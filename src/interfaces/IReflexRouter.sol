// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IReflexRouter {
    /// @notice Triggers a backrun swap the profit created by the swap.
    /// @param triggerPoolId The pool ID to trigger the backrun on.
    /// @param swapAmountIn The amount to swap in.
    /// @param token0In Whether token0 is being swapped in.
    /// @param recipient The address to receive the profit.
    /// @return  profit The profit made from the backrun swap.
    function triggerBackrun(bytes32 triggerPoolId, uint112 swapAmountIn, bool token0In, address recipient)
        external
        returns (uint256 profit, address profitToken);

    /// @notice Returns the admin/owner address of the Reflex router.
    /// @return The address of the admin/owner.
    function getReflexAdmin() external view returns (address);

    /// @notice Emitted when a backrun is executed
    /// @param triggerPoolId The pool ID that triggered the backrun
    /// @param swapAmountIn The amount swapped in
    /// @param token0In Whether token0 was being swapped in
    /// @param profit The profit made from the backrun
    /// @param profitToken The token in which profit was made
    /// @param recipient The address that received the profit
    event BackrunExecuted(
        bytes32 indexed triggerPoolId,
        uint112 swapAmountIn,
        bool token0In,
        uint256 profit,
        address profitToken,
        address indexed recipient
    );
}
