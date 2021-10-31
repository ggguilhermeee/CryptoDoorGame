//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

contract GameLogic {

    // Data Contracts *******

    // This contains all information about game session.
    // All rewards in each level.
    // All moves made by user in each round.
    // All doors that contains wins and loses.
    struct GameState {
        
        mapping(uint256 => Level) levels;

    }

    // This represents the level the player is in
    struct Level {

        // The number of the level played.
        uint256 level; 

        // The player reward if win.
        uint256 reward;

        // The number of rounds of this level
        mapping(uint256 => Round) rounds;

    }

    // This represents a round in each level
    struct Round {

        // The number of the round in the level x.
        uint8 roundNumber;

        // The move player made in this round.
        uint8 move;

        mapping(uint256 => Door) doors;
    }

    // This represents a door that the player needs to choose.
    struct Door {
        
        // The number of the door to be choosen by player
        uint8 doorNumber;

        // True and player wins.
        // False and player loses this sessions.
        bool willWin;

    }

    struct GameSession {

        // The id of the game session.
        // This id is used as a key for the mapping of all existing sessions.
        uint256 id;

        // The current level the user is playing in this session.
        uint120 currentLevel;

        // The current round the user is playing in this session.
        uint120 currentRound;

        // Player won this session.
        // TODO Review this later. This can be subtitute by checking in game state the last door.willWin
        bool won;

        // The player has left the session and claim all rewards with him
        bool leftSession;

        // All the state of this session including rewards and all doors that will lose the game.
        GameState state;
    }

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

    // Constants *******

    // Fee in wei to start a game session.
    uint256 private feeInWei;

    // Number of sessions occured.
    // This is used as a game session unique identifier.
    uint256 private gameSessionCount;

    // State *******

    // Metadata by player address
    mapping(address => PlayerMeta) private metadataByPlayer;

    // Game session by game session id
    mapping(uint256 => GameSession) private gameSessions;



    // Functions *******

    constructor(uint256 _feeInWei){
        feeInWei = _feeInWei;
    }

    function isPlayerPlaying(address player) public view returns(bool) {
        return metadataByPlayer[player].gameSessionId != 0;
    }

    function getPlayerWinsCount(address player) public view returns(uint256) {
        return metadataByPlayer[player].wins;
    }

    function getPlayerLossersCount(address player) public view returns(uint256) {
        return metadataByPlayer[player].wins;
    }

    function getPlayerCancelationSessionsCount(address player) public view returns(uint256) {
        return metadataByPlayer[player].wins;
    }

    function startGameSession() external payable returns(uint256) {
        // A fee is needed to play the game
        require(msg.value >= feeInWei, "Need fee to play the game");

        // A session can only be started when a player does not has an active session
        require(isPlayerPlaying(msg.sender), "Active session already exists.");
        
        // Increments the number of gameSessions and this is used as the session identifier
        gameSessionCount++;

        // Invokes oracle to produce random game session
        randomizeState();

        return gameSessionCount;   
    }

    function randomizeState() internal {

    }
}