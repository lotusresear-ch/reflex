# Test Utils

This directory contains shared testing utilities and mock contracts used across the Reflex project test suites.

## MockToken

A comprehensive ERC20 mock token designed for testing purposes with additional utility functions:

### Features

- **Standard ERC20**: Full ERC20 implementation using OpenZeppelin contracts
- **Flexible Creation**: Create tokens with custom name, symbol, and initial supply
- **Testing Utilities**: Additional functions for test convenience

### Functions

#### Creation Functions (via TestUtils library)

- `createMockToken(name, symbol, initialSupply)`: Create a custom token
- `createStandardMockToken()`: Create a standard "MockToken" with 1M tokens

#### Testing Utility Functions

- `mint(to, amount)`: Mint tokens to any address (for test setup)
- `burn(from, amount)`: Burn tokens from any address (for test cleanup)
- `setBalance(account, amount)`: Set an account's balance directly (for state manipulation)

### Usage Examples

```solidity
import "../utils/TestUtils.sol";

contract MyTest is Test {
    MockToken public token;

    function setUp() public {
        // Create standard token
        token = MockToken(TestUtils.createStandardMockToken());

        // Or create custom token
        address customToken = TestUtils.createMockToken("Custom", "CST", 500 * 10**18);
    }

    function testSomething() public {
        // Set up test state
        token.setBalance(alice, 1000 * 10**18);
        token.mint(bob, 500 * 10**18);

        // Run your tests...
    }
}
```

### Import Remapping

The project uses `@reflex/` remapping for cleaner imports from the source directory:

````solidity
// Clean imports using remapping
import "@reflex/integrations/FundsSplitter/FundsSplitter.sol";
import "@reflex/interfaces/IReflexRouter.sol";

// Instead of relative paths
import "../../src/integrations/FundsSplitter/FundsSplitter.sol";
import "../../src/interfaces/IReflexRouter.sol";
```## Benefits

1. **DRY Principle**: No duplicate MockToken implementations
2. **Consistency**: Same token behavior across all tests
3. **Enhanced Features**: Additional testing utilities not available in basic ERC20
4. **Maintainability**: Single place to update mock token logic
5. **Flexibility**: Support for both standard and custom token creation

## Used By

- `test/integrations/FundsSplitter/FundsSplitter.test.s.sol`: Testing fund splitting logic
- `test/integrations/ReflexAfterSwap.test.s.sol`: Testing backrun profit distribution
- Any future tests requiring ERC20 token mocks
````
