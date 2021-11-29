//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "./GameLogic.sol";

contract GameApi is GameLogic {

    constructor(
        uint256 _feeToOpenSession, 
        address _vrfCoordinator, 
        address _linkToken,
        uint256 _vrfFee,
        bytes32 _keyHash,
        string memory _uri) GameLogic(_feeToOpenSession, _vrfCoordinator, _linkToken, _vrfFee, _keyHash, _uri) {}

    /// @dev Starts a new session for caller player.
    /// The players needs to pay a fee to open a new session
    /// if not an exception is thrown and the state is all reverted.
    /// @return Returns the id of the new session.
    function openSession() external payable returns (uint256) {
        return super._startGameSession();
    }

    /// @dev closes a session for caller player.
    function closeSession() external {
        super._leaveSession();
    }

    /// @dev player plays a round by choosing the door
    /// which wants to be opened.
    function play(uint256 _doorNumber) external {
        super._play(_doorNumber);
    }

    function getCreatedSessionsCounter() public view returns (uint256) {
        return playerSessionCount;
    }

}