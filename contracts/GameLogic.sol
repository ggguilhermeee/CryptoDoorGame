//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./GameCore.sol";

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

// @dev Contains game logic.
contract GameLogic is GameCore, VRFConsumerBase {

    /*** CONSTANTS ***/
    
    bytes32 internal keyHash;
    uint256 internal fee;

    /*** STATE ***/

    /// @dev Random numper per requestId
    mapping(bytes32 => uint256) internal requestIdToRandomNumber;

    /// @dev Address of the player to requestid
    /// This doesnt not store history
    mapping(address => bytes32) internal addressToRequestId;

    /*** EVENTS ***/

    event PlayerOpenSession(address indexed _player, uint256 indexed sessionId);

    event PlayerClosesSession(address indexed _player, uint256 indexed sessionId);

    event RequestRandom(address indexed _player, bytes32 indexed _requestId);

    /*** FUNCTIONS ***/

    constructor(
        uint256 _feeToOpenSession, 
        address _vrfCoordinator, 
        address _linkToken, 
        uint256 _vrfFee, 
        bytes32 _keyHash) VRFConsumerBase(_vrfCoordinator,_linkToken)
    {
        keyHash = _keyHash;
        fee = _vrfFee;

        feeToOpenSession = _feeToOpenSession; // Fee to start session

        finalLevel = 7; // ChangeToBeParameterLater
    }

    /// @dev Called by chainlink to return our random number.
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        //addressToRequestId[] = 0
        //randomResult = randomness;
    }

    /// @dev Checks if the player already has and active session.
    /// @param _player The player we want to query.
    function isPlayerPlaying(address _player) public view returns(bool) {
        return metadataByPlayer[_player].playerSessionId != 0;
    }

    /// @dev Checks how many wins a player has.
    /// @param _player The player we want to query.
    function getPlayerWinsCount(address _player) public view returns(uint256) {
        return metadataByPlayer[_player].wins;
    }

    /// @dev Checks how many losses a player has.
    /// @param _player The player we want to query.
    function getPlayerLossersCount(address _player) public view returns(uint256) {
        return metadataByPlayer[_player].losses;
    }

    /// @dev Checks how many game sessions a player cancelate.
    /// @param _player The player we want to query.
    function getPlayerCancelationSessionsCount(address _player) public view returns(uint256) {
        return metadataByPlayer[_player].cancelations;
    }

    /// @dev This function will start a new game session.
    /// For this to happen the user needs to pay a fee.
    /// For this to happen a player cannot has an active session.
    function _startGameSession() internal returns(uint256) {

        // A fee is needed to play the game
        require(msg.value == feeToOpenSession, "Need to pay the right fee.");

        address player = msg.sender;

        // A session can only be started when a player does not has an active session
        require(!isPlayerPlaying(player), "Active session already exists.");
        
        // Increments the number of playerSessions and this is used as the session identifier
        uint256 newPlayerSessionId = ++playerSessionCount;

        metadataByPlayer[player].playerSessionId = newPlayerSessionId;

        emit PlayerOpenSession(player, newPlayerSessionId);
        
        return newPlayerSessionId;   
    }

    /// @dev Player makes a move in a session.
    /// @param _choosedDoor The choosed door by the player.
    /// Returns true if the player choosed the right door false if player choosed the wrong door.
    function _play(uint256 _choosedDoor) internal {

        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        
        address player = msg.sender;

        require(isPlayerPlaying(player), "No session active to play.");
        
        require(addressToRequestId[player] != 0, "Already requested a random number.");
        
        PlayerMeta storage playerMetadata = metadataByPlayer[player];
        GameSession storage playerSession = playerSessions[playerMetadata.playerSessionId];

        // The final level will always have two doors to choose.
        // This means that the number of doors is (maxLevel - currLevel) + 2
        // The door choosen by the player must be between the door number on and the 
        // result of the formula above.
        uint256 doorsAmount = _getNumberOfDoorByLevel(playerSession.currentLevel);
        require(_choosedDoor > 0 && _choosedDoor <= doorsAmount, "You choosed non-existing door.");

        string memory movesKey = _getPlayerMovesKey(
            player,
            playerMetadata.playerSessionId,
            playerSession.currentLevel,
            playerSession.currentRound
        );

        // This will not happen because of the first check. When player loses isPlayerPlaying returns false.
        // Only for protection.
        // The way the logic is handled when we loose or cancel a game session we
        // no longer can modify the state of the last session and the first required
        // for this method will fail.
        require(playerMovesBySessionsLevelAndRound[movesKey] != 0, "You already made a move.");

        bytes32 requestId = requestRandomness(keyHash, fee);

        addressToRequestId[player] = requestId;
        
        emit RequestRandom(player, requestId);
    }

    /// @dev Player makes a move in a session.
    /// @param _choosedDoor The choosed door by the player.
    /// Returns true if the player choosed the right door false if player choosed the wrong door.
    function _play2(uint256 _choosedDoor) internal returns (bool) {
        address player = msg.sender;

        require(isPlayerPlaying(player), "No session active to play.");

        PlayerMeta storage playerMetadata = metadataByPlayer[player];
        GameSession storage playerSession = playerSessions[playerMetadata.playerSessionId];

        // The final level will always have two doors to choose.
        // This means that the number of doors is (maxLevel - currLevel) + 2
        // The door choosen by the player must be between the door number on and the 
        // result of the formula above.
        uint256 doorsAmount = _getNumberOfDoorByLevel(playerSession.currentLevel);
        require(_choosedDoor > 0 && _choosedDoor <= doorsAmount, "You choosed non-existing door.");

        string memory movesKey = _getPlayerMovesKey(
            player,
            playerMetadata.playerSessionId,
            playerSession.currentLevel,
            playerSession.currentRound
        );

        // This will not happen because of the first check. When player loses isPlayerPlaying returns false.
        // Only for protection.
        // The way the logic is handled when we loose or cancel a game session we
        // no longer can modify the state of the last session and the first required
        // for this method will fail.
        require(playerMovesBySessionsLevelAndRound[movesKey] != 0, "You already made a move.");

        playerMovesBySessionsLevelAndRound[movesKey] = _choosedDoor;

        // Gets the key of the mapper that stores the all the results of all created doors
        string memory doorResultKey = _getDoorResultKey(
            playerMetadata.playerSessionId,
            playerSession.currentLevel,
            playerSession.currentRound,
            _choosedDoor
        );

        // Gets random number result for the door

        bool won = doorResultBySessionLevelRoundAndDoor[doorResultKey];

        if(won) {
            // Player won the round.
            if (playerSession.currentRound == roundsNumberPerLevel) {
                // The player won this session
                if(playerSession.currentLevel == finalLevel) {
                    playerSession.won = true;   
                    //TODO COLLECT REWARDS.
                }
                // The player won this level. Reset rounds and increment level.
                else {
                    playerSession.currentRound = 1;
                    playerSession.currentLevel++;
                }
            }
        }
        // Player lost the game.
        else {
            // This is not needed. The won is initialized as 0 => false.
            playerSession.won = false;
            
            playerMetadata.playerSessionId = 0;
        }

        return won;
    }

    /// @dev Method to let players leave their sessions and reclaim 
    /// all of the rewards.
    function _leaveSession() internal {
        require(isPlayerPlaying(msg.sender), "Cannot leave empty session.");

        PlayerMeta storage playerMetadata = metadataByPlayer[msg.sender];

        uint256 cancelledSession = playerMetadata.playerSessionId;

        playerSessions[cancelledSession].leftSession = true;

        playerMetadata.playerSessionId = 0;
        playerMetadata.cancelations++;

        //TODO COLLECT REWARDS.

        emit PlayerClosesSession(msg.sender, cancelledSession);
    }

    /// @dev The last level will have only two doors to choose to be 50% winning the round.
    /// The more doors we have the bigger the probability to win.
    /// So per each level up we want to decrease the number of doors until it gets 50% on last level.
    /// This can be described by the formula (Final Level - Current Level) + 2 = Number of doors n the current level.
    /// @param _currLevel This is the current level the player are in.
    function _getNumberOfDoorByLevel(
        uint256 _currLevel
        ) internal view returns (uint256) {

        return (finalLevel - _currLevel) + 2;
    }

    /// @dev Get the composite key to get the right reward by session and level.
    /// @param _session The session of the player.
    /// @param _level The level of the reward.
    function _getRewardsKey(
        uint256 _session, 
        uint256 _level
        ) internal pure returns (string memory) {
                
        return string(abi.encodePacked(_session, _level));
    }

    /// @dev Get the composite key to get the value a door number holds.
    /// @param _session The session to search for.
    /// @param _level The level to search for.
    /// @param _round The round to search for.
    /// @param _doorNumber The door number to search for.
    function _getDoorResultKey(
        uint256 _session, 
        uint256 _level,
        uint256 _round,
        uint256 _doorNumber
        ) internal pure returns (string memory) {
                
        return string(abi.encodePacked(_session, _level, _round, _doorNumber));
    }
    
    /// @dev Get the composite key to get the moves a player makes
    /// @param _player The address of the player.
    /// @param _session The session to search for.
    /// @param _level The level to search for.
    /// @param _round The round to search for.
    function _getPlayerMovesKey(
        address _player,
        uint256 _session, 
        uint256 _level,
        uint256 _round
        ) internal pure returns (string memory) {
                
        return string(abi.encodePacked(_player, _session, _level, _round));
    }
}