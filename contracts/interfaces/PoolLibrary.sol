// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library PoolLibrary {
    using SafeMath for uint256;

    function withdrawableVestingTokens(
        uint256 tgeTime,
        uint256 cycle,
        uint256 tokensReleaseEachCycle,
        uint256 tgeTokensRelease,
        uint256 totalVestingTokens,
        uint256 totalVestedTokens
    ) internal view returns (uint256) {
        if (tgeTime == 0) return 0;
        if (block.timestamp < tgeTime) return 0;
        if (cycle == 0) return 0;

        uint256 currentTotal = 0;

        if (block.timestamp >= tgeTime) {
            currentTotal = block.timestamp
            .sub(tgeTime)
            .div(cycle)
            .mul(tokensReleaseEachCycle)
            .add(tgeTokensRelease);
        }

        uint256 withdrawable = 0;

        if (currentTotal > totalVestingTokens) {
            withdrawable = totalVestingTokens.sub(totalVestedTokens);
        } else {
            withdrawable = currentTotal.sub(totalVestedTokens);
        }

        return withdrawable;
    }

    function getContributionAmount(
        uint256 contributed,
        uint256 minContribution,
        uint256 maxContribution,
        uint256 availableToBuy
    ) internal pure returns (uint256, uint256) {
        // Bought all their allocation
        if (contributed >= maxContribution) {
            return (0, 0);
        }
        uint256 remainingAllocation = maxContribution.sub(contributed);

        // How much bnb is one token
        if (availableToBuy > remainingAllocation) {
            if (contributed > 0) {
                return (0, remainingAllocation);
            } else {
                return (minContribution, remainingAllocation);
            }
        } else {
            if (contributed > 0) {
                return (0, availableToBuy);
            } else {
                if (availableToBuy < minContribution) {
                    return (0, availableToBuy);
                } else {
                    return (minContribution, availableToBuy);
                }
            }
        }
    }

    function convertCurrencyToToken(
        uint256 amount,
        uint256 rate,
        uint8 decimals
    ) internal pure returns (uint256) {
        return amount.mul(rate).div(10**decimals);
    }

    function addLiquidity(
        address router,
        address token,
        uint256 liquidityBnb,
        uint256 liquidityToken,
        address pool,
        address baseToken
    ) internal returns (uint256 liquidity) {
        IERC20(token).approve(router, liquidityToken);
        if(baseToken == address(0)) {
            (,, liquidity) = IUniswapV2Router02(router).addLiquidityETH{value: liquidityBnb}(
                token,
                liquidityToken,
                liquidityToken,
                liquidityBnb,
                pool,
                block.timestamp
            );
        } else {
            IERC20(baseToken).approve(router, liquidityBnb);
            (,, liquidity) = IUniswapV2Router02(router).addLiquidity(
                baseToken,
                token,
                liquidityBnb,
                liquidityToken,
                liquidityBnb,
                liquidityToken,
                pool,
                block.timestamp
            );
        }
    }

    function calculateFeeAndLiquidity(
        uint256 totalRaised,
        uint256 ethFeePercent,
        uint256 tokenFeePercent,
        uint256 totalVolumePurchased,
        uint256 liquidityPercent,
        uint256 liquidityListingRate
    ) internal pure returns (uint256 bnbFee, uint256 tokenFee, uint256 liquidityBnb, uint256 liquidityToken) {
        bnbFee = totalRaised.mul(ethFeePercent).div(100);
        tokenFee = totalVolumePurchased.mul(tokenFeePercent).div(100);
        liquidityBnb = totalRaised.sub(bnbFee).mul(liquidityPercent).div(100);
        liquidityToken = liquidityBnb.mul(liquidityListingRate);
    }
}
