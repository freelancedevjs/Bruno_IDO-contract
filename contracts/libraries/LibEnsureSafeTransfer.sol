// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../utils/Utility.sol";


library LibEnsureSafeTransfer {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using Address for address payable;

    modifier validAddress(address _address) {
        require(_address != address(0), "INVALID ADDRESS");
        _;
    }
    modifier validAmount(uint _amount) {
        require(_amount >= 0, "INVALID AMOUNT");
        _;
    }

    function safeTransferFromEnsureExactAmount(
        address token,
        address sender,
        address recipient,
        uint256 amount
    ) internal validAddress(token) validAddress(sender) validAddress(recipient) validAmount(amount) {
        uint256 oldRecipientBalance = IERC20Upgradeable(token).balanceOf(
            recipient
        );
        IERC20Upgradeable(token).safeTransferFrom(sender, recipient, amount);
        uint256 newRecipientBalance = IERC20Upgradeable(token).balanceOf(
            recipient
        );
        require(
            newRecipientBalance - oldRecipientBalance == amount,
            "Not enough token was transferred If tax set Remove Our Address!!"
        );
    }

    function transferEnsureExactAmount(
        address token,
        address recipient,
        uint256 amount
    ) internal validAddress(token) validAddress(recipient) validAmount(amount)  {
        uint256 oldRecipientBalance = IERC20Upgradeable(token).balanceOf(
            recipient
        );
        IERC20Upgradeable(token).safeTransfer(recipient, amount);
        uint256 newRecipientBalance = IERC20Upgradeable(token).balanceOf(
            recipient
        );
        require(
            newRecipientBalance - oldRecipientBalance == amount,
            "Not enough token was transferred If tax set Remove Our Address!!"
        );
    }

    function transferExactNativeOrToken(
        address token,
        address recipient,
        uint256 amount
    ) internal  {
        if(token == address(0)) {
            transferExactNative(recipient, amount);
        } else {
            transferEnsureExactAmount(token, recipient, amount);
        }
    }

    function transferExactNative(
        address recipient,
        uint256 amount
    ) internal validAddress(recipient) validAmount(amount) {
        uint256 oldRecipientBalance = address(recipient).balance;

        payable(recipient).sendValue(amount);

        uint256 newRecipientBalance = address(recipient).balance;
        require(
            newRecipientBalance - oldRecipientBalance == amount,
            "Not enough token was transferred If tax set Remove Our Address!!"
        );
    }

    function safeTransferFrom(
        address token,
        address sender,
        address recipient,
        uint256 amount
    ) internal validAddress(token) validAddress(sender) validAddress(recipient) validAmount(amount) {
        IERC20Upgradeable(token).safeTransferFrom(sender, recipient, amount);
    }

    function safeTransfer(
        address token,
        address recipient,
        uint256 amount
    ) internal validAddress(token) validAddress(recipient) validAmount(amount)  {
        IERC20Upgradeable(token).safeTransfer(recipient, amount);
    }

    function transferNativeOrToken(
        address token,
        address recipient,
        uint256 amount
    ) internal  {
        if(token == address(0)) {
            transferNative(recipient, amount);
        } else {
            safeTransfer(token, recipient, amount);
        }
    }

    function transferNative(
        address recipient,
        uint256 amount
    ) internal validAddress(recipient) validAmount(amount) {
        payable(recipient).sendValue(amount);
    }
}
