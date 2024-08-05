// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../libraries/LibPresale.sol";

interface IPool {
    function initialize(
        LibPresale.Presale memory presale,
        address[2]  memory _linkAddress, // [0] poolOwner ,[1] = adminWallet
        uint8 _version
    ) external;

    function emergencyWithdrawToken( address payaddress ,address tokenAddress, uint256 tokens ) external;
    function getPoolInfo() external view returns (address, uint8[] memory , uint256[] memory , string memory , string memory);
}
