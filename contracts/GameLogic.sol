//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

contract GameLogic {

    /*** DATA TYPES ***/

    /// @dev This represents the game session the player is playing
    struct GameSession {

        // The current level the user is playing in this session.
        uint256 currentLevel;

        // The current round the user is playing in this session.
        uint256 currentRound;

        // Player won this session.
        bool won;

        // The player has left the session and claim all rewards with him
        bool leftSession;

        // The block date containing this new session.
        uint createDate;
    }

    /// @dev This has metadata for a player
    struct PlayerMeta {
        
        // Number of times the player wins the game;
        uint256 wins;

        // Number of times the player lose the game;
        uint256 losses;

        // Number of times the player leave the session;
        uint256 cancelations;

        // The id number of the current session the user is playing
        // If user does not have any session activated this number will be 0 and a new session should be created
        uint256 playerSessionId;

        // All sessions the user has been played.
        // TODO this should be a mapper address => uint256[] - ids of sessions
        GameSession[] gameHistory;
    }

    /*** CONSTANTS ***/

    /// @dev Fee in wei to start a game session.
    uint256 private feeInWei;

    /// @dev Number of sessions occured.
    /// This is used as a game session unique identifier.
    uint256 private playerSessionCount;

    /// @dev Final level.
    uint120 private finalLevel;

    /// @dev Rounds per level.
    uint120 private roundsNumberPerLevel; 


    /*** STATES ***/

    /// @dev Metadata by player address
    mapping(address => PlayerMeta) private metadataByPlayer;

    /// @dev Game session by game session id
    mapping(uint256 => GameSession) private playerSessions;

    /// @dev This mapper holds all rewards by session and level;
    /// The key is a string composed by enconding session id and level
    /// The value is the id of the nft reward.
    mapping(string => uint256) private rewardsBySessionAndLevel;

    /// @dev this mapper holds all results (fail or win) of doors by session, level, round and door number.
    /// The key is a string composed by enconding the session id, level, round and door number.
    /// The value is true if the door is safe or false if the door is an obstacle.
    mapping(string => bool) private doorResultBySessionLevelRoundAndDoor;

    /// @dev this mapper holds all moves made by players.
    /// The key is a string composed by player address, session id, level and round.
    /// The value should give the move choosed by the player.
    mapping(string => uint256) private playerMovesBySessionsLevelAndRound;

    /*** FUNCTIONS ***/

    constructor(uint256 _feeInWei){
        feeInWei = _feeInWei;
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
    function startGameSession() external payable returns(uint256) {
        // A fee is needed to play the game
        require(msg.value >= feeInWei, "Need fee to play the game");

        // A session can only be started when a player does not has an active session
        require(!isPlayerPlaying(msg.sender), "Active session already exists.");
        
        // Increments the number of playerSessions and this is used as the session identifier
        playerSessionCount++;

        metadataByPlayer[msg.sender].playerSessionId = playerSessionCount;

        // Invokes oracle to produce random game session
        randomizeState();

        return playerSessionCount;   
    }

    /// @dev Player makes a move in a session.
    /// @param _choosedDoor The choosed door by the player.
    /// Returns true if the player choosed the right door false if player choosed the wrong door.
    function play(uint256 _choosedDoor) external returns (bool) {
        address player = msg.sender;

        require(isPlayerPlaying(player), "No session active to play.");

        PlayerMeta storage playerMetadata = metadataByPlayer[player];
        GameSession storage playerSession = playerSessions[playerMetadata.playerSessionId];

        // The final level will always have two doors to choose.
        // This means that the number of doors is (maxLevel - currLevel) + 2
        // The door choosen by the player must be between the door number on and the 
        // result of the formula above.
        uint256 lastDoorNumber = getNumberOfDoorByLevel(playerSession.currentLevel);
        require(_choosedDoor > 0 && _choosedDoor <= lastDoorNumber, "You choosed non-existing door.");

        string memory movesKey = getPlayerMovesKey(
            player,
            playerMetadata.playerSessionId,
            playerSession.currentLevel,
            playerSession.currentRound
        );

        // Only for protection.
        // The way the logic is handled when we loose or cancel a game session we
        // no longer can modify the state of the last session and the first required
        // for this method will fail.
        require(playerMovesBySessionsLevelAndRound[movesKey] != 0, "You already made a move.");

        playerMovesBySessionsLevelAndRound[movesKey] = _choosedDoor;

        string memory doorResultKey = getDoorResultKey(
            playerMetadata.playerSessionId,
            playerSession.currentLevel,
            playerSession.currentRound,
            _choosedDoor
        );

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
    function leaveSession() external {
        require(isPlayerPlaying(msg.sender), "Cannot leave empty session.");

        PlayerMeta storage playerMetadata = metadataByPlayer[msg.sender];

        playerSessions[playerMetadata.playerSessionId].leftSession = true;

        playerMetadata.playerSessionId = 0;
        playerMetadata.cancelations++;

        //TODO COLLECT REWARDS.
    }

    /// @dev TESTES FUNCITON
    /// TODO TO BE REMOVED
    function randomizeState() internal {
        uint256 playerSessionId = playerSessionCount;

        GameSession storage session = playerSessions[playerSessionId];

        // Creating sessiong
        session.currentLevel = 1;
        session.currentRound = 1;

        // Keys
        string memory rewardKey = getRewardsKey(playerSessionId, 1);
        string memory doorResultKey = getDoorResultKey(playerSessionId, 1, 1, 1);
        string memory door2ResultKey = getDoorResultKey(playerSessionId, 1, 1, 2);

        rewardsBySessionAndLevel[rewardKey] = 23;
        
        doorResultBySessionLevelRoundAndDoor[doorResultKey] = true;
        doorResultBySessionLevelRoundAndDoor[door2ResultKey] = false;

    }

    /// @dev The last level will have only two doors to choose to be 50% winning the round.
    /// The more doors we have the bigger the probability to win.
    /// So per each level up we want to decrease the number of doors until it gets 50% on last level.
    /// This can be described by the formula (Final Level - Current Level) + 2 = Number of doors n the current level.
    /// @param _currLevel This is the current level the player are in.
    function getNumberOfDoorByLevel(uint256 _currLevel) internal view returns (uint256) 
    {
        return (finalLevel - _currLevel) + 2;
    }

    /// @dev Get the composite key to get the right reward by session and level.
    /// @param _session The session of the player.
    /// @param _level The level of the reward.
    function getRewardsKey(
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
    function getDoorResultKey(
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
    function getPlayerMovesKey(
        address _player,
        uint256 _session, 
        uint256 _level,
        uint256 _round
        ) internal pure returns (string memory) {
                
        return string(abi.encodePacked(_player, _session, _level, _round));
    }
}