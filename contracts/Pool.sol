// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IPoolFactory.sol";
import "./interfaces/PoolLibrary.sol";
import "./interfaces/IERC20Info.sol";
import "./libraries/LibPresale.sol";
import "./libraries/LibEnsureSafeTransfer.sol";
import "./utils/Utility.sol";


contract Pool is OwnableUpgradeable, IPool , ReentrancyGuard, Utility {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address payable;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint8 public VERSION;
    uint public MINIMUM_LOCK_DAYS = 30 days;

    enum PoolState {
        inUse,
        completed,
        cancelled
    }

    enum PoolType {
        presale,
        privatesale,
        fairsale
    }

    // address public governance;
    address payable private feeWallet;
    address public payment_currency;

    address public token;
    uint256 public rate;
    IERC721 public nftAddress;
    uint256 public min_payment;
    uint256 public max_payment;
    uint256 public softCap;
    uint256 public hardCap;

    uint256 public startTime;
    uint256 public endTime;

    uint256 public emergencyWithdrawFees;

    PoolState public poolState;
    PoolType public poolType;

    uint256 public totalRaised;
    uint256 public totalVolumePurchased;
    uint256 public totalClaimed;
    uint256 public totalRefunded;

    uint256 public tvl;

    mapping(address => uint256) public contributionOf;
    mapping(address => uint256) public purchasedOf;
    mapping(address => uint256) public claimedOf;
    mapping(address => uint256) public refundedOf;

    uint256 public tgeDate; // TGE date for vesting locks, unlock date for normal locks
    uint256 public tgeBps; // In bips. Is 0 for normal locks
    uint256 public cycle; // Is 0 for normal locks
    uint256 public cycleBps; // In bips. Is 0 for normal locks

    bool public useWhitelisting;
    uint256 public publicStartTime;

    LibTier.Tier public tier1;

    event Contributed(
        address indexed pool_address,
        uint256 value,
        address user,
        uint256 totalRaised
    );

    event ContributionWithdrawn(address indexed pool_address, uint256 amount, uint256 fees, address user);

    event Claimed(address indexed pool_address, uint256 total_claimed, uint256 pending_claim, address user_address);

    event Finalized(address indexed pool_address, address user, address token, uint256 token_supply, uint256 total_raised);

    event Cancelled(address indexed pool_address, uint256 timestamp);
    event RateChanged(address indexed pool_address, uint256 _old_rate, uint256 _new_rate);

    event WhitelistChanged(bool _whitelist);
    event PoolPublicStartAtChanged(uint256 timestamp, uint256 start_at);
    event PoolTierChanged(uint256 timestamp, uint256 _endTime1, uint256 _publicStartTime);

    event EmergencyLiquidityWithdrawn(address indexed pool_address, address user, uint256 amount, address pair);

    event EmergencyWithdrawn(address indexed pool_address, address user, uint256 amount, address pair);
    event LiquidityWithdrawn(address indexed pool_address, address user, uint256 amount, address payment_currency);

    modifier inProgress() {
        require(poolState == PoolState.inUse, "Pool is either completed or cancelled");
        if(useWhitelisting && address(nftAddress) != address(0) && publicStartTime > block.timestamp) {
            if(
                block.timestamp >= tier1.startTime &&
                block.timestamp < tier1.endTime
            ) {
                require(nftAddress.balanceOf(_msgSender()) > 0, "Invalid User");
            }
        }
        require(block.timestamp >= startTime && block.timestamp < endTime, "It's not time to buy");
        require(totalRaised < hardCap, "Hardcap reached");
        _;
    }

    modifier onlyAdmin() {
        require(IPoolFactory(owner()).admin(_msgSender()) ||owner() == _msgSender(),"Ownable: caller is not the admin");
        _;
    }


    modifier notInProgress() {
        require(poolState == PoolState.inUse, "Pool is either started or completed or cancelled");
        require(startTime >= block.timestamp, "Pool has started");
        _;
    }

    function initialize(
        LibPresale.Presale memory presale,
        address[2]  memory _linkAddress, // [0] poolOwner ,[1] = feeWallet
        uint8 _version
    ) external override initializer {
        require(presale.min_payment <= presale.max_payment, "Min contribution amount must be less than or equal to max");
        require(presale.softCap.mul(2) >= presale.hardCap && presale.softCap <= presale.hardCap && presale.hardCap > 0, "Softcap must be >= 50% of hardcap");
        require(presale.startTime >= (block.timestamp + 600), "Start time should be in the future, at least 10 minutes from now");
        require(presale.startTime < presale.endTime, "End time must be after start time");

        require(presale.cycle >= 0, "Invalid cycle");
        require(presale.tgeBps >= 0 && presale.tgeBps < 10_000, "Invalid bips for TGE");
        require(presale.cycleBps >= 0 && presale.cycleBps < 10_000, "Invalid bips for cycle");
        require(
            presale.tgeBps + presale.cycleBps <= 10_000,
            "Sum of TGE bps and cycle should be less than 10000"
        );
        if(presale.tier1.endTime > 0) {
            require(presale.startTime < presale.tier1.endTime, "Presale Start time must be before Tier 1 end time");
            require(presale.endTime >= presale.tier1.endTime, "Presale End time must be after Tier 1 end time");
        }

        if(presale.publicStartTime > 0) {
            require(presale.endTime >= presale.publicStartTime && presale.startTime < presale.publicStartTime, "Presale End time must be after Public Start Time");
        }

        OwnableUpgradeable.__Ownable_init();

        tier1 = presale.tier1;

        if(presale.nftAddress != address(0)) {
            nftAddress = IERC721(presale.nftAddress);
        }

        emergencyWithdrawFees = presale.emergencyWithdrawFees;
        transferOwnership(_linkAddress[0]);
        feeWallet = payable(_linkAddress[1]);
        // governance = presale.governance;
        rate = presale.rate;
        min_payment = presale.min_payment;
        max_payment = presale.max_payment;
        softCap = presale.softCap;
        hardCap = presale.hardCap;
        startTime = presale.startTime;
        endTime = presale.endTime;
        payment_currency = presale.payment_currency;
        poolState = PoolState.inUse;
        VERSION = _version;
        poolType = PoolType.presale;

        useWhitelisting = presale.useWhitelist;
        publicStartTime = presale.publicStartTime;

        tgeBps = presale.tgeBps;
        cycle = presale.cycle;
        cycleBps = presale.cycleBps;
    }

    function getPoolInfo() external override view returns (address, uint8[] memory , uint256[] memory , string memory , string memory){

        uint8[] memory state = new uint8[](3);
        uint256[] memory info = new uint256[](8);

        state[0] = uint8(poolState);
        state[1] = uint8(poolType);
        state[2] = IERC20Info(token).decimals();
        info[0] = startTime;
        info[1] =  endTime;
        info[2] =  totalRaised;
        info[3] = hardCap;
        info[4] = softCap;
        info[5] = min_payment;
        info[6] = max_payment;
        info[7] = rate;

        return (token , state , info , IERC20Info(token).name() , IERC20Info(token).symbol());
    }


    function contribute(uint256 _funds) public payable inProgress nonReentrant returns (bool) {
        uint256 requiredFunds = 0;
        if(payment_currency == address(0)) {
            requiredFunds = msg.value;
        } else {
            requiredFunds = _funds;
            LibEnsureSafeTransfer.safeTransferFromEnsureExactAmount(payment_currency, msg.sender, address(this), requiredFunds);
        }
        require(requiredFunds > 0, "Cant contribute 0");

        uint256 userTotalContribution = contributionOf[msg.sender].add(requiredFunds);
        // Allow to contribute with an amount less than min contribution
        // if the remaining contribution amount is less than min
        if (hardCap.sub(totalRaised) >= min_payment) {
            require(userTotalContribution >= min_payment, "Min contribution not reached");
        }
        require(userTotalContribution <= max_payment, "Contribute more than allowed");
        require(totalRaised.add(requiredFunds) <= hardCap, "Buying amount exceeds hard cap");

        contributionOf[msg.sender] = userTotalContribution;
        totalRaised = totalRaised.add(requiredFunds);
        if(token != address(0)) {
            uint8 decimals = getPaymentTokenDecimals();
            uint256 volume = PoolLibrary.convertCurrencyToToken(requiredFunds, rate, decimals);
            require(volume > 0, "Contribution too small to produce any volume");
            purchasedOf[msg.sender] = purchasedOf[msg.sender].add(volume);
            totalVolumePurchased = totalVolumePurchased.add(volume);
        }
        emit Contributed(address(this), requiredFunds, msg.sender, totalVolumePurchased);
        return true;
    }

    function claim() public nonReentrant {
        require(poolState == PoolState.completed, "Owner has not closed the pool yet");
        require(tgeDate <= block.timestamp , "pool still not finalized!!!");
        uint256 volume = purchasedOf[msg.sender];
        uint256 totalClaim = claimedOf[msg.sender];
        if (volume == 0 && totalClaim == 0) {
            uint8 decimals = getPaymentTokenDecimals();
            purchasedOf[msg.sender] = volume = PoolLibrary.convertCurrencyToToken(
                contributionOf[_msgSender()],
                rate,
                decimals
            );
            require(volume > 0, "Contribution too small to produce any volume");
            totalVolumePurchased = totalVolumePurchased.add(volume);
        }

        uint256 withdrawable = 0;

        if (tgeBps > 0) {
            withdrawable = _withdrawableTokens(msg.sender);
        }
        else{
            if(volume >= totalClaim){
                withdrawable = volume.sub(totalClaim);
            }
        }

        require(withdrawable > 0 , "No token avalible for claim!!");
        claimedOf[msg.sender] += withdrawable;
        totalClaimed = totalClaimed.add(withdrawable);
        LibEnsureSafeTransfer.transferEnsureExactAmount(token, msg.sender, withdrawable);
        emit Claimed(address(this), volume, withdrawable, msg.sender);
    }


    function _withdrawableTokens(address _userAddress)
    internal
    view
    returns (uint256)
    {
        uint256 volume = purchasedOf[_userAddress];
        uint256 totalClaim = claimedOf[_userAddress];
        if (volume == 0) return 0;
        if (totalClaim >= volume) return 0;
        if (block.timestamp < tgeDate) return 0;
        if (cycle == 0) return 0;

        uint256 tgeReleaseAmount = Math.mulDiv(
            volume,
            tgeBps,
            10_000
        );
        uint256 cycleReleaseAmount = Math.mulDiv(
            volume,
            cycleBps,
            10_000
        );
        uint256 currentTotal = (((block.timestamp - tgeDate) / cycle) * cycleReleaseAmount) + tgeReleaseAmount; // Truncation is expected here
        uint256 withdrawable = 0;
        if (currentTotal > volume) {
            withdrawable = volume - totalClaim;
        } else {
            withdrawable = currentTotal - totalClaim;
        }
        return withdrawable;
    }

    function withdrawContribution() external nonReentrant {
        if (poolState == PoolState.inUse) {
            require(block.timestamp >= endTime, "Pool is still in progress");
            require(totalRaised < softCap, "Soft cap reached");
        } else {
            require(poolState == PoolState.cancelled, "Cannot withdraw contribution because pool is completed");
        }
        require(contributionOf[msg.sender] > 0, "You Don't Have Enough contribution");
        _withdrawContribution(contributionOf[msg.sender], 0);
    }

    function finalize(address _token, uint256 _totalSupply) external onlyAdmin nonReentrant {
        require(_token != address(0), "Invalid Address");
        require(poolState == PoolState.inUse, "Pool was finialized or cancelled");
        require(
            totalRaised == hardCap || hardCap.sub(totalRaised) < min_payment ||
            (totalRaised >= softCap && block.timestamp > endTime),
            "It is not time to finish"
        );
        token = _token;
        poolState = PoolState.completed;

        tgeDate = block.timestamp;

        LibEnsureSafeTransfer.safeTransferFromEnsureExactAmount(
            token,
            _msgSender(),
            address(this),
            _totalSupply
        );
        emit Finalized(address(this), msg.sender, token, _totalSupply, totalRaised);
    }

    function cancel() external onlyAdmin {
        require (poolState == PoolState.inUse, "Pool was either finished or cancelled");
        poolState = PoolState.cancelled;
        emit Cancelled(address(this), block.timestamp);
    }

    function withdrawLeftovers() external onlyAdmin {
        require(block.timestamp >= endTime, "It is not time to withdraw leftovers");
        require(totalRaised < softCap, "Soft cap reached, call finalize() instead");
        LibEnsureSafeTransfer.transferEnsureExactAmount(token, feeWallet, IERC20(token).balanceOf(address(this)));
    }


    function setRate(uint256 _rate) external onlyAdmin {
        require(poolState == PoolState.inUse, "Pool is either started or completed or cancelled");
        emit RateChanged(address(this),rate, _rate);
        rate = _rate;
    }

    function emergencyWithdrawContribution() public payable nonReentrant returns (bool) {
        require(poolState == PoolState.inUse, "Pool is either completed or cancelled");
        require(block.timestamp >= startTime && block.timestamp < endTime, "You can not withdraw now");
        require(contributionOf[msg.sender] > 0, "You Don't Have Enough contribution");
        uint256 refundAmount = contributionOf[msg.sender];
        uint256 _withdrawFee = refundAmount * emergencyWithdrawFees / 10_000;
        refundAmount = refundAmount - _withdrawFee;
        _withdrawContribution(refundAmount, _withdrawFee);
        return true;
    }

    function _withdrawContribution(uint256 _refundAmount, uint256 _fees) internal  {
        totalVolumePurchased = totalVolumePurchased.sub(purchasedOf[msg.sender]);

        refundedOf[msg.sender] = _refundAmount;
        totalRefunded = totalRefunded.add(_refundAmount.add(_fees));
        contributionOf[msg.sender] = 0;
        purchasedOf[msg.sender] = 0;
        totalRaised = totalRaised.sub(_refundAmount.add(_fees));
        LibEnsureSafeTransfer.transferExactNativeOrToken(payment_currency, msg.sender, _refundAmount);
        if(_fees > 0) {
            LibEnsureSafeTransfer.transferExactNativeOrToken(payment_currency, feeWallet, _fees);
        }

        emit ContributionWithdrawn(address(this), _refundAmount, _fees, msg.sender);
    }

    function emergencyWithdrawToken( address payaddress ,address tokenAddress, uint256 tokens ) external override onlyOwner
    {
        LibEnsureSafeTransfer.transferNativeOrToken(tokenAddress, payaddress, tokens);
        emit EmergencyWithdrawn(address(this), msg.sender, tokens, tokenAddress);
    }

    function withdrawLiquidity() external onlyAdmin {
        require(poolState == PoolState.inUse, "Pool is either started or completed or cancelled");
        require(
            totalRaised == hardCap || hardCap.sub(totalRaised) < min_payment ||
            (totalRaised >= softCap && block.timestamp >= endTime),
            "It is not time to withdrawLiquidity"
        );
        uint256 balance = 0;
        if(payment_currency == address(0)) {
            balance = address(this).balance;
        } else {
            balance = IERC20(payment_currency).balanceOf(address(this));
        }
        LibEnsureSafeTransfer.transferExactNativeOrToken(payment_currency, feeWallet, balance);
        emit LiquidityWithdrawn(address(this), msg.sender, balance, payment_currency);
    }

    function userAvailableClaim(address _userAddress) public view returns (uint256){
        return _withdrawableTokens(_userAddress);
    }

    function startPublicSaleNow() external onlyAdmin inProgress {
        publicStartTime = block.timestamp;
        useWhitelisting = false;
        emit PoolPublicStartAtChanged(block.timestamp, publicStartTime);
    }

    function changeWhitelist(bool _whitelist) external onlyAdmin {
        useWhitelisting = _whitelist;
        if(_whitelist == false) {
            tier1.endTime = 0;
            publicStartTime = 0;
        }
        emit WhitelistChanged(_whitelist);
    }

    function changeTierDates(uint256 _endTime1, uint256 _publicStartTime) external onlyAdmin notInProgress {
        require (poolState == PoolState.inUse, "Pool was either finished or cancelled");
        require(_endTime1 > startTime && _endTime1 <= endTime
        && _publicStartTime >= _endTime1 && _publicStartTime <= endTime, "Invalid End Time");

        tier1.endTime = _endTime1;
        publicStartTime = _publicStartTime;
        useWhitelisting = true;
        emit PoolTierChanged(block.timestamp, _endTime1, _publicStartTime);
    }

    function getPaymentTokenDecimals() public view returns(uint8)  {
        uint8 decimals = 18;
        if(payment_currency != address(0)) {
            decimals = IERC20Info(payment_currency).decimals();
        }
        return decimals;
    }
}
