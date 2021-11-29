//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "../GameLogic.sol";

contract ExposedGameLogic is GameLogic {

 constructor(
        uint256 _feeToOpenSession, 
        address _vrfCoordinator, 
        address _linkToken,
        uint256 _vrfFee,
        bytes32 _keyHash,
        string memory _uri) GameLogic(_feeToOpenSession, _vrfCoordinator, _linkToken, _vrfFee, _keyHash, _uri) {}

    function getFinalLevel() external view returns (uint120){
        return finalLevel;
    }

    function getNumberOfDoorByLevel(
        uint256 _currLevel
        ) external view returns (uint256) {

        return super._getNumberOfDoorByLevel(_currLevel);
    }

    function getRewardsKey(
        uint256 _session, 
        uint256 _level
        ) external view returns (string memory) {
            console.log(string(abi.encodePacked(_session, _level)));
            console.log(_level);
        return super._getRewardsKey(_session, _level);
    }

    function getDoorResultKey(
        uint256 _session, 
        uint256 _level,
        uint256 _round,
        uint256 _doorNumber
        ) external pure returns (string memory) {

        return super._getDoorResultKey(_session, _level, _round, _doorNumber);        
    }
    
    function getPlayerMovesKey(
        address _player,
        uint256 _session, 
        uint256 _level,
        uint256 _round
        ) external pure returns (string memory) {
            
        return super._getPlayerMovesKey(_session, _level, _round);
    }

}
