//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "./GameLogic.sol";

contract ExposedGameLogic is GameLogic {

 constructor(uint256 _feeInWei) GameLogic(_feeInWei) {}

}