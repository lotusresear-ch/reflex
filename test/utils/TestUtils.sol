// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title TestUtils
/// @notice Shared utilities and mock contracts for testing
library TestUtils {
    /// @notice Creates a new MockToken instance
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param initialSupply The initial supply to mint to the deployer
    /// @return The address of the deployed MockToken
    function createMockToken(string memory name, string memory symbol, uint256 initialSupply)
        internal
        returns (address)
    {
        MockToken token = new MockToken(name, symbol, initialSupply);
        return address(token);
    }

    /// @notice Creates a standard MockToken with default values
    /// @return The address of the deployed MockToken
    function createStandardMockToken() internal returns (address) {
        return createMockToken("MockToken", "MOCK", 1000000 * 10 ** 18);
    }
}

/// @title MockToken
/// @notice Mock ERC20 token for testing purposes
contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }

    /// @notice Mint tokens to an address (for testing convenience)
    /// @param to The address to mint tokens to
    /// @param amount The amount of tokens to mint
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @notice Burn tokens from an address (for testing convenience)
    /// @param from The address to burn tokens from
    /// @param amount The amount of tokens to burn
    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    /// @notice Set the balance of an address directly (for testing convenience)
    /// @param account The address to set the balance for
    /// @param amount The new balance amount
    function setBalance(address account, uint256 amount) external {
        uint256 currentBalance = balanceOf(account);
        if (currentBalance < amount) {
            _mint(account, amount - currentBalance);
        } else if (currentBalance > amount) {
            _burn(account, currentBalance - amount);
        }
    }
}
