# Reflex Test Suite

This directory contains all test files for the Reflex project, organized following standard Foundry conventions.

## Directory Structure

```
test/
├── integrations/
│   ├── FundsSplitter/
│   │   └── FundsSplitter.test.s.sol     # Tests for fund splitting functionality
│   └── ReflexAfterSwap.test.s.sol       # Tests for backrun integration
├── utils/
│   ├── TestUtils.sol                    # Shared testing utilities and MockToken
│   ├── TestUtils.test.s.sol             # Tests for testing utilities
│   └── README.md                        # Documentation for test utilities
└── README.md                            # This file
```

## Test Coverage

### Integration Tests (55 tests)

**FundsSplitter Tests (37 tests)**

- ✅ Basic ERC20/ETH splitting functionality
- ✅ Dust handling and remainder distribution
- ✅ Access control and admin functions
- ✅ Edge cases and error conditions
- ✅ Fuzz testing for various input combinations
- ✅ Invariant testing for state consistency
- ✅ Event emission verification

**ReflexAfterSwap Tests (18 tests)**

- ✅ Constructor and initialization
- ✅ Access control with router admin
- ✅ Backrun execution and profit distribution
- ✅ Router interaction and error handling
- ✅ Reentrancy protection
- ✅ Multiple backrun scenarios
- ✅ Edge cases and large amounts

### Utility Tests (5 tests)

**TestUtils Tests (5 tests)**

- ✅ MockToken creation functions
- ✅ Token manipulation utilities (mint, burn, setBalance)
- ✅ Standard and custom token creation

## Running Tests

```bash
# Run all tests
forge test

# Run specific test suite
forge test --match-contract FundsSplitterTest
forge test --match-contract ReflexAfterSwapTest
forge test --match-contract TestUtilsTest

# Run with verbosity
forge test -v

# Run specific test function
forge test --match-test testSplitERC20BasicFunctionality
```

## Test Utilities

The `test/utils/` directory contains shared utilities:

- **MockToken**: Enhanced ERC20 mock with testing utilities
- **TestUtils**: Library functions for creating tokens and test setup
- See `test/utils/README.md` for detailed documentation

## Adding New Tests

When adding new tests:

1. Place test files in appropriate subdirectories under `/test`
2. Use shared utilities from `/test/utils/TestUtils.sol`
3. Follow existing naming conventions (`*.test.s.sol`)
4. Include comprehensive test coverage for new functionality
5. Update this README if adding new test categories
