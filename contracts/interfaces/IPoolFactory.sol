// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

interface IPoolFactory {
    function increaseTotalValueLocked(uint256 value) external;
    function decreaseTotalValueLocked(uint256 value) external;
    function removePoolForToken(address token, address pool) external;
    function recordContribution(address user, address pool) external;
    function addTopPool(address poolAddress, uint256 raisedAmount) external;
    function removeTopPool(address poolAddress) external;
    function removePrivatePoolForToken(string memory tokenName, address pool) external;
    function getEmergencyWithdrawFees() external view returns(uint256);

    function admin(address) view external returns(bool) ;

    event TvlChanged(uint256 totalLocked, uint256 totalRaised);
    event ContributionUpdated(uint256 totalParticipations);
    event PoolForTokenRemoved(address indexed token, address pool);
}

