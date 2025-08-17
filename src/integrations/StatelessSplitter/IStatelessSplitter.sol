// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IStatelessSplitter
/// @notice Interface for a stateless ETH/ERC20 fund splitter contract
interface IStatelessSplitter {
    /// @notice Returns the current recipient list and their share percentages in basis points
    /// @return recipients List of recipient addresses
    /// @return sharesBps Corresponding list of share amounts in basis points (1% = 100 bps)
    function getRecipients() external view returns (address[] memory recipients, uint256[] memory sharesBps);

    /// @notice Splits `amount` of ERC20 tokens (caller must approve the splitter beforehand)
    /// @param token Address of the ERC20 token
    /// @param amount Amount of tokens to split
    function splitERC20(address token, uint256 amount) external;

    /// @notice Splits msg.value ETH according to the current share configuration
    function splitETH() external payable;

    /// @notice Updates the recipients and their shares (admin only)
    /// @param recipients List of recipient addresses
    /// @param sharesBps List of corresponding shares in basis points (1% = 100 bps)
    function updateShares(address[] calldata recipients, uint256[] calldata sharesBps) external;
}
