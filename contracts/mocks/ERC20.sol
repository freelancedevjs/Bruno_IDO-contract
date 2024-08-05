pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract BaseERC20 is ERC20 {
    uint8 private _decimals = 18;
    constructor(string memory name_,string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
        _mint(msg.sender, 100000000*1e18);
    }

    function decimals() public view override(ERC20) returns (uint8) {
        return _decimals;
    }
}
