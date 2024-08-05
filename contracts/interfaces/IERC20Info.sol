// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IERC20Info {
    function decimals() external view returns (uint8);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function supply() external view returns (uint256);
}
