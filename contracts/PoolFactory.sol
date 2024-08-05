// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IPoolFactory.sol";
import "./interfaces/PoolLibrary.sol";
import "./interfaces/IERC20Info.sol";
import "./libraries/LibPresale.sol";
import "./libraries/LibEnsureSafeTransfer.sol";
import "./utils/Utility.sol";

contract PoolFactory is OwnableUpgradeable, Utility {
    address public master;
    using SafeMath for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    address public poolOwner;
    uint8 public version;
    using Clones for address;
    address payable public feeWallet;
    mapping(address => bool) public paymentCurrencies;

     mapping(address => bool) public admin;


    event PresalePoolCreated(address indexed pool_address, LibPresale.Presale presale);
    event VersionChanged(uint256 _newVersion, uint256 _oldVersion);
    event PoolFeesUpdated(string _feeType, uint256 _newFees, uint256 _oldFees);

    modifier onlyAdmin() {
        require(admin[msg.sender] ||owner() == _msgSender(),"Ownable: caller is not the admin");
        _;
    }


    function initialize(
        address _master,
        uint8 _version
    )
    validAddress(_master)
    external initializer {
        __Ownable_init();
        master = _master;
        version = _version;
        paymentCurrencies[address(0)] = true;
        admin[_msgSender()] = true;

    }

    function setMasterAddress(address _address) public onlyOwner validAddress(_address) {
        master = _address;
    }

    function setFeeWallet(address payable _address) public onlyOwner validAddress(_address) {
        feeWallet = _address;
    }

    function setVersion(uint8 _version) public onlyOwner {
        require(_version > version, "Invalid Version");
        emit VersionChanged(_version, version);
        version = _version;
    }

    function setPaymentCurrency(address index, bool status) public onlyOwner {
        paymentCurrencies[index] = status;
    }

    function addAdmin(address _toAdd) onlyOwner public {
        require(_toAdd != address(0));
        admin[_toAdd] = true;
    }

    function addMultiAdmins(address[] memory _toAdd) onlyOwner public {

        for(uint i =0 ; i < _toAdd.length;i++){
            require(_toAdd[i] != address(0));
            admin[_toAdd[i]] = true;
        }
    }

    function removeAdmin(address _toRemove) onlyOwner public {

        require(_toRemove != address(0));
        require(_toRemove != _msgSender());
        admin[_toRemove] = false;
    }

    function removeMultiAdmins(address[] memory _toRemove) onlyOwner public {
        for(uint i =0 ; i< _toRemove.length ; i++){
            require(_toRemove[i] != address(0));
            require(_toRemove[i] != _msgSender());
            admin[_toRemove[i]] = false;

        }
    }

    function getPaymentCurrency(address index) public view returns (bool) {
        return paymentCurrencies[index];
    }

    function initializeClone(
        address _pair,
        LibPresale.Presale memory presale
    ) internal  {
        IPool(_pair).initialize(
            presale,
            [poolOwner, feeWallet],
            version
        );
    }

    function createSale(
        LibPresale.Presale memory presale
    ) external payable
    onlyAdmin
    {
        require(master != address(0), "pool address is not set!!");
        require(paymentCurrencies[presale.payment_currency] == true || address(0) == presale.payment_currency, "Invalid payment token");
        //fees transfer to Fee wallet
        (bool success, ) = feeWallet.call{ value: msg.value }("");
        require(success, "Address: unable to send value, recipient may have reverted");

        bytes32 salt = keccak256(
            abi.encodePacked(presale.salt, block.timestamp)
        );
        address pair = Clones.cloneDeterministic(master, salt);
        //Clone Contract
        initializeClone(
            pair,
            presale
        );
        emit PresalePoolCreated(pair, presale);
    }

    function setPoolOwner(address _address) public onlyOwner {
        require(_address != address(0), "Invalid Address found");
        poolOwner = _address;
    }


    function bnbLiquidity(address payable _receiver, uint256 _amount)
    public
    onlyOwner
    validAddress(_receiver)
    validAmount(_amount)
    {
        LibEnsureSafeTransfer.transferNative(_receiver, _amount);
    }

    function transferAnyERC20Token(
        address payaddress,
        address tokenAddress,
        uint256 tokens
    ) public onlyOwner {
        LibEnsureSafeTransfer.transferEnsureExactAmount(tokenAddress, payaddress, tokens);
    }

    function poolEmergencyWithdrawToken(
        address poolAddress,
        address payaddress,
        address tokenAddress,
        uint256 tokens
    ) public onlyOwner {
        IPool(poolAddress).emergencyWithdrawToken(
            payaddress,
            tokenAddress,
            tokens
        );
    }


}
