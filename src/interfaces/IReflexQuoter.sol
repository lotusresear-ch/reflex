// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.6;
pragma abicoder v2;

interface IReflexQuoter {
    struct SwapDecodedData {
        address[] pools;
        uint8[] dexType;
        uint8[] dexMeta;
        uint112 amount;
        address[] tokens;
    }

    function getQuote(address pool, uint8 assetId, uint256 swapAmountIn)
        external
        returns (uint256 profit, SwapDecodedData memory decoded, uint256[] memory amountsOut, uint256 initialHopIndex);
}
