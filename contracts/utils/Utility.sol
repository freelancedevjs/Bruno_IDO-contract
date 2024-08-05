// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

abstract contract Utility {
    event GovernanceChanged(address indexed pool_address, address _old, address _new);

    modifier validAddress(address _address) {
        require(_address != address(0), "INVALID ADDRESS");
        _;
    }
    modifier validAmount(uint _amount) {
        require(_amount >= 0, "INVALID AMOUNT");
        _;
    }
}
