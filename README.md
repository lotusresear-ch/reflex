# Lotus Reflex

![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue.svg)
![Foundry](https://img.shields.io/badge/Built%20with-Foundry-red.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![MEV](https://img.shields.io/badge/MEV-Capture%20Engine-green.svg)
![DeFi](https://img.shields.io/badge/DeFi-Integration-purple.svg)
![Tests](https://img.shields.io/badge/Tests-127%20Passing-brightgreen.svg)

**Lotus Reflex** is a sophisticated on-chain MEV (Maximum Extractable Value) capture engine designed for seamless integration into DEX protocols, specifically optimized for Algebra-based AMM systems. The system captures MEV opportunities while maintaining safety, decentralization, and ensuring zero interference with pool state or user experience.

## 🚀 Key Features

### Core MEV Functionality

- **Non-Intrusive Design**: Operates without affecting pool state or user transactions
- **Real-time MEV Capture**: Automatically detects and captures profitable opportunities after each swap
- **Failsafe Mechanisms**: Robust error handling prevents any disruption to normal DEX operations
- **Gas Optimized**: Minimal overhead with efficient execution paths

### Advanced Control Systems

- **Runtime Enable/Disable**: Toggle MEV capture functionality without contract redeployment
- **Authorization Framework**: Leverages existing Algebra authorization system for secure access control
- **Configurable Profit Sharing**: Split captured profits between swap recipients and fund distribution
- **Plugin-Level Integration**: Seamlessly integrates with Algebra's plugin architecture
- **Fee Exemption System**: Automatic fee exemption for MEV capture transactions to prevent self-taxation

### Safety & Security

- **Reentrancy Protection**: Built-in guards against reentrancy attacks
- **Dust Handling**: Proper handling of token remainders to prevent value loss
- **Comprehensive Testing**: 127+ tests covering all functionality and edge cases
- **MIT Licensed**: Open source with permissive licensing

## 🏗️ Architecture

### Core Components

#### `AlgebraBasePluginV3`

The main plugin contract that integrates with Algebra pools:

- Implements Algebra's plugin interface with sliding fees, farming proxy, and volatility oracle
- Contains enable/disable toggle for MEV capture functionality
- Handles the `afterSwap` hook to trigger MEV capture
- **Fee exemption logic**: Automatically sets zero fees for reflexRouter transactions in `beforeSwap` hook
- Uses existing Algebra authorization system (`ALGEBRA_BASE_PLUGIN_MANAGER` role)

#### `ReflexAfterSwap`

Abstract base contract for MEV capture logic:

- Implements the core profit extraction and distribution mechanism
- Configurable recipient share functionality (up to 50% of profits)
- Integration with `FundsSplitter` for multi-party profit distribution
- Reentrancy-protected with comprehensive validation

#### `FundsSplitter`

Handles distribution of captured profits:

- Supports multiple recipients with configurable shares
- Basis points system for precise percentage allocation
- Handles both ERC20 tokens and ETH distribution
- Dust handling ensures no value is lost

### Integration Flow

1. **Swap Execution**: User performs swap on Algebra pool
2. **Fee Calculation**: `beforeSwap` hook calculates fees (zero for reflexRouter, normal fees for others)
3. **Hook Trigger**: `afterSwap` hook is called by the pool
4. **MEV Check**: Plugin checks if MEV capture is enabled
5. **Profit Extraction**: If enabled, triggers backrun through ReflexRouter (with zero fees)
6. **Profit Distribution**: Captured profits are split between recipient and fund distribution
7. **Failsafe**: Any errors are caught to prevent disruption

## 🛠️ Technical Features

### Enable/Disable Functionality

```solidity
// Enable or disable MEV capture at runtime
function setReflexEnabled(bool _enabled) external;

// Check current state
function reflexEnabled() external view returns (bool);
```

### Recipient Share Configuration

```solidity
// Set percentage of profits to send directly to swap recipient
function setRecipientShare(uint256 _recipientShareBps) external;

// Maximum 50% (5000 basis points) allowed
// Remaining profits go to FundsSplitter distribution
```

### Fee Exemption System

```solidity
// Automatic fee exemption in beforeSwap hook
function beforeSwap(address sender, ...) external override returns (bytes4, uint24, uint24) {
    // Calculate sliding fee
    uint16 newFee = _getFeeAndUpdateFactors(zeroToOne, currentTick, lastTick);

    // Exempt reflexRouter from fees to prevent self-taxation
    if (sender == getRouter()) {
        newFee = 0;
    }

    return (selector, newFee, 0);
}

// Get current router address
function getRouter() public view returns (address);
```

**Key Benefits:**

- **Prevents Self-Taxation**: MEV capture transactions don't pay fees to themselves
- **Cost Efficiency**: Maximizes profit extraction by eliminating unnecessary fee overhead
- **Works with Sliding Fees**: Integrates perfectly with Algebra's dynamic fee system

### Authorization

- Uses Algebra's existing `ALGEBRA_BASE_PLUGIN_MANAGER` role
- Secure, battle-tested authorization framework
- No custom access control needed

## 📊 Testing

Comprehensive test suite with **127 passing tests**:

### Test Categories

- **Unit Tests**: Individual component functionality
- **Integration Tests**: Full system behavior testing
- **Fuzz Tests**: Property-based testing with random inputs
- **Edge Cases**: Boundary conditions and error scenarios
- **Authorization Tests**: Access control verification
- **Profit Distribution Tests**: Recipient share validation
- **Fee Exemption Tests**: ReflexRouter fee exemption verification

### Running Tests

```shell
# Run all tests
forge test

# Run specific test categories
forge test --match-contract AlgebraBasePluginV3Test
forge test --match-contract ReflexAfterSwapTest
forge test --match-contract FundsSplitterTest

# Run fee exemption tests specifically
forge test --match-test "test_BeforeSwap_.*"

# Run with gas reporting
forge test --gas-report

# Run with coverage
forge coverage
```

## 📋 Development Setup

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

### Installation

```shell
# Clone the repository
git clone https://github.com/lotusresear-ch/reflex.git
cd reflex

# Install dependencies
forge install

# Build the project
forge build

# Run tests
forge test
```

### Project Structure

```
src/
├── integrations/
│   ├── algebra/
│   │   └── full/
│   │       └── AlgebraBasePluginV3.sol    # Main plugin contract
│   └── ReflexAfterSwap.sol                # MEV capture logic
├── FundsSplitter.sol                      # Profit distribution
└── interfaces/                           # Contract interfaces

test/
├── integrations/                         # Integration tests
├── utils/                               # Test utilities
└── mocks/                              # Mock contracts
```

## 🔧 Configuration Examples

### Basic Plugin Deployment

```solidity
// Deploy with MEV capture enabled by default
AlgebraBasePluginV3 plugin = new AlgebraBasePluginV3(
    poolAddress,
    factoryAddress,
    pluginFactoryAddress,
    baseFee,
    reflexRouterAddress
);
```

### Runtime Configuration

```solidity
// Disable MEV capture
plugin.setReflexEnabled(false);

// Set 25% of profits to go directly to swap recipient
plugin.setRecipientShare(2500); // 2500 basis points = 25%

// Re-enable MEV capture
plugin.setReflexEnabled(true);
```

### Fee Exemption in Action

```solidity
// When a normal user swaps - they pay the calculated fee
user.swap() -> beforeSwap(normalUser, ...) -> fee = 500 (0.05%)

// When reflexRouter performs MEV capture - zero fee automatically applied
reflexRouter.triggerBackrun() -> beforeSwap(reflexRouter, ...) -> fee = 0 (0%)

// Verification
assert(plugin.getRouter() == address(reflexRouter));
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and add tests
4. Ensure all tests pass (`forge test`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Related Projects

- [Algebra Protocol](https://github.com/cryptoalgebra/AlgebraV3) - The underlying AMM protocol
- [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts) - Security and utility contracts
- [Foundry](https://github.com/foundry-rs/foundry) - Development framework

## 📞 Support

For questions, issues, or contributions, please:

- Open an issue on GitHub
- Review the test suite for usage examples
- Check the documentation in the code comments

---

**⚠️ Disclaimer**: This software is provided as-is. Users should conduct their own testing and security reviews before deploying to production environments.

## 🛠️ Development Commands

### Build

```shell
forge build
```

### Test

```shell
# Run all tests
forge test

# Run with verbosity
forge test -v

# Run specific tests
forge test --match-test "testReflexAfterSwap"
forge test --match-contract "AlgebraBasePluginV3Test"

# Run with gas reporting
forge test --gas-report
```

### Code Quality

```shell
# Format code
forge fmt

# Generate gas snapshots
forge snapshot

# Generate coverage report
forge coverage
```

### Local Development

```shell
# Start local blockchain
anvil

# Deploy contracts (example)
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --private-key <key> --broadcast

# Interact with contracts
cast call <contract_address> "reflexEnabled()" --rpc-url http://localhost:8545
```

## 🆘 Help

```shell
forge --help
anvil --help
cast --help
```

## 📚 Additional Resources

- [Foundry Book](https://book.getfoundry.sh/) - Comprehensive Foundry documentation
- [Algebra Documentation](https://docs.algebra.finance/) - Algebra protocol documentation
- [Solidity Documentation](https://docs.soliditylang.org/) - Solidity language reference
