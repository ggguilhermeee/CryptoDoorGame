// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@chainlink/contracts/src/v0.6/VRFCoordinator.sol";

contract VRFCoordinatorMock is VRFCoordinator {

    constructor(address _link, address _blockHashStore) VRFCoordinator(_link, _blockHashStore) public {}

    function fufillRandomNumberMock(address _target, bytes32 _requestId, uint256 _randomness) external{
        _target.call(abi.encodeWithSignature("rawFulfillRandomness(bytes32,uint256)", _requestId, _randomness));
    }
}