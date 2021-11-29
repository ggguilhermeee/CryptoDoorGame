//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

/// @dev Contains the core data of the game.
contract GameCore is ERC1155 {

    /*** DATA TYPES ***/

    /// @dev This structure is metadata to be used when chainlink fulfill the random number.
    struct RandomRequestMetadata {
        
        address player;

        uint256 playerMove;

        uint256 maxNumberOfDoors;
    }
    
    /// @dev This represents the game session the player is playing
    struct GameSession {

        // The current level the user is playing in this session.
        uint256 currentLevel;

        // The current round the user is playing in this session.
        uint256 currentRound;

        // The player has left the session and claim all rewards with him
        bool leftSession;

        // The block date containing this new session.
        uint createDate;

        // Moves per level and round.
        mapping (string => uint256) playerMoves;

        // Rewards per level.
        mapping (string => uint256) rewards;

        // Failing door.
        mapping (string => uint256) wrongDoor;
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
    }

    /*** CONSTANTS ***/

    /// @dev Fee in wei to start a game session.
    uint256 internal feeToOpenSession;

    /// @dev Number of sessions occured.
    /// This is used as a game session unique identifier.
    uint256 internal playerSessionCount;

    /// @dev Final level.
    uint120 internal finalLevel;

    /// @dev Rounds per level.
    uint120 internal roundsNumberPerLevel;

    /*** STATES ***/

    /// @dev Metadata by player address
    mapping(address => PlayerMeta) internal metadataByPlayer;

    /// @dev Game session by game session id
    mapping(uint256 => GameSession) internal playerSessions;

    constructor(string memory _uri) ERC1155(_uri){}
}