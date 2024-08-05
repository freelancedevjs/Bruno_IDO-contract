pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./LibTier.sol";


library LibPresale {

    struct Presale {
        address governance;
        uint256 salt;

        uint256 emergencyWithdrawFees;
        address nftAddress;
        address payment_currency;
        uint256 rate;
        uint256 min_payment;
        uint256 max_payment;
        uint256 softCap;
        uint256 hardCap;

        uint256 startTime;
        uint256 endTime;

        uint256 tgeBps;
        uint256 cycle;
        uint256 cycleBps;

        bool useWhitelist;
        uint256 publicStartTime;
        LibTier.Tier tier1;
    }
}
