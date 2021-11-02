//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

contract GameLogic {

    /*** DATA TYPES ***/

    /// @dev This represents the game session the player is playing
    struct GameSession {

        // The id of the game session.
        // This id is used as a key for the mapping of all existing sessions.
        uint256 id;

        // The current level the user is playing in this session.
        uint256 currentLevel;

        // The current round the user is playing in this session.
        uint256 currentRound;

        // Player won this session.
        // TODO Review this later. This can be subtitute by checking in game state the last door.willWin
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
        uint256 gameSessionId;

        // All sessions the user has been played.
        GameSession[] gameHistory;
    }

    /*** CONSTANTS ***/

    /// @dev Fee in wei to start a game session.
    uint256 private feeInWei;

    /// @dev Number of sessions occured.
    /// This is used as a game session unique identifier.
    uint256 private gameSessionCount;

    /// @dev Final level.
    uint120 private finalLevel;

    /// @dev Rounds per level.
    uint120 private roundsNumberPerLevel; 


    /*** STATES ***/

    /// @dev Metadata by player address
    mapping(address => PlayerMeta) private metadataByPlayer;

    /// @dev Game session by game session id
    mapping(uint256 => GameSession) private gameSessions;

    /// @dev This mapper holds all rewards by session and level;
    /// The key is a string composed by enconding session id and level
    /// The value is the id of the nft reward.
    mapping(string => uint256) private rewardsBySessionAndLevel;

    /// @dev this mapper holds all results (fail or win) of doors by session, level and round
    /// The key is a string composed by enconding the session id, level and the round.
    /// The value is true if the door is safe or false if the door is an obstacle.
    mapping(string => bool) private doorResultBySessionLevelAndRound;

    /// @dev this mapper holds all moves made by players.
    /// The key is a string composed by 
    mapping(string => uint256) private playerMovesBySessionsLevelAndRound;

    /*** FUNCTIONS ***/

    constructor(uint256 _feeInWei){
        feeInWei = _feeInWei;
    }

    /// @dev Checks if the player already has and active session.
    /// @param _player The player we want to query.
    function isPlayerPlaying(address _player) public view returns(bool) {
        return metadataByPlayer[_player].gameSessionId != 0;
    }

    /// @dev Checks how many wins a player has.
    /// @param _player The player we want to query.
    function getPlayerWinsCount(address _player) public view returns(uint256) {
        return metadataByPlayer[_player].wins;
    }

    /// @dev Checks how many losses a player has.
    /// @param _player The player we want to query.
    function getPlayerLossersCount(address _player) public view returns(uint256) {
        return metadataByPlayer[_player].wins;
    }

    /// @dev Checks how many game sessions a player cancelate.
    /// @param _player The player we want to query.
    function getPlayerCancelationSessionsCount(address _player) public view returns(uint256) {
        return metadataByPlayer[_player].wins;
    }

    /// @dev This function will start a new game sessions.
    /// For this to happen the user needs to pay a fee.
    /// For this to happen a player cannot has an active session.
    /// All of the random rewards and winning doors are calculated in this function through an oracle.
    function startGameSession() external payable returns(uint256) {
        // A fee is needed to play the game
        require(msg.value >= feeInWei, "Need fee to play the game");

        // A session can only be started when a player does not has an active session
        require(!isPlayerPlaying(msg.sender), "Active session already exists.");
        
        // Increments the number of gameSessions and this is used as the session identifier
        gameSessionCount++;

        // Invokes oracle to produce random game session
        randomizeState();

        return gameSessionCount;   
    }

    /// @dev Player makes a move in a session.
    /// @param _choosedDoor The choosed door by the player.
    /// Returns true if the player choosed the right door false if player choosed the wrong door.
    function play(uint256 _choosedDoor) external {

    }

    function leaveSession() external {
        require(!isPlayerPlaying(msg.sender), "Cannot leave empty session.");

        gameSessions[metadataByPlayer[msg.sender].gameSessionId].leftSession = true;

        metadataByPlayer[msg.sender].gameSessionId = 0;
        metadataByPlayer[msg.sender].cancelations++;
    }

    function randomizeState() internal {
        metadataByPlayer[msg.sender].gameSessionId = gameSessionCount;

        GameSession storage session = gameSessions[gameSessionCount];
        uint256 gameSessionId = gameSessionCount;

        // Creating sessiong
        session.id = gameSessionId;
        session.currentLevel = 1;
        session.currentRound = 1;

        // Keys
        string memory rewardKey = getRewardsKey(gameSessionId, 1);
        string memory doorResultKey = getDoorResultKey(gameSessionId, 1, 1);
        string memory door2ResultKey = getDoorResultKey(gameSessionId, 1, 2);

        rewardsBySessionAndLevel[rewardKey] = 23;
        
        doorResultBySessionLevelAndRound[doorResultKey] = true;
        doorResultBySessionLevelAndRound[door2ResultKey] = false;

    }

    function getRewardsKey(
        uint256 session, 
        uint256 level
        ) internal pure returns (string memory) {
                
        return string(abi.encodePacked(session, level));
    }

    function getDoorResultKey(
        uint256 session, 
        uint256 level,
        uint256 round
        ) internal pure returns (string memory) {
                
        return string(abi.encodePacked(session, level, round));
    }
    
    function getPlayerMovesKey(
        address player,
        uint256 session, 
        uint256 level,
        uint256 round
        ) internal pure returns (string memory) {
                
        return string(abi.encodePacked(player, session, level, round));
    }
}