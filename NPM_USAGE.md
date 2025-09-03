# NPM Package Usage

## Installation

```bash
npm install @lotus-research/reflex
```

## Usage

### Import Contract Sources

```typescript
import { contracts, interfaces, libraries } from "@lotus-research/reflex";

// Get contract source paths
const reflexRouterPath = contracts.ReflexRouter;
const pluginPath = contracts.AlgebraBasePluginV3;
const interfacePath = interfaces.IReflexRouter;
```

### Using with Hardhat

Works out of the box with Hardhat projects:

```javascript
// hardhat.config.js
module.exports = {
  solidity: "0.8.20",
  // No special configuration needed for Reflex
};
```

Then import directly in your Solidity contracts:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@lotus-research/reflex/src/ReflexRouter.sol";
import "@lotus-research/reflex/src/integrations/algebra/full/AlgebraBasePluginV3.sol";

contract MyContract {
    // Use Reflex contracts
}
```

### Using with Foundry

Add to your `foundry.toml`:

```toml
[profile.default]
remappings = [
    "@reflex/=node_modules/@lotus-research/reflex/src/",
    # ... other remappings
]
```

Then import in your Solidity files:

```solidity
import "@reflex/ReflexRouter.sol";
import "@reflex/integrations/algebra/full/AlgebraBasePluginV3.sol";
```

### Direct Import

You can also import directly from the package:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@lotus-research/reflex/src/ReflexRouter.sol";
import "@lotus-research/reflex/src/integrations/algebra/full/AlgebraBasePluginV3.sol";

contract MyContract {
    // Use Reflex contracts
}
```

## Available Contracts

### Core Contracts

- `ReflexRouter`: Main router contract for MEV capture
- `ReflexAfterSwap`: Abstract base contract for after-swap MEV logic
- `FundsSplitter`: Profit distribution contract

### Algebra Integration

- `AlgebraBasePluginV3`: Main plugin for Algebra pools with MEV capture

### Interfaces

- `IReflexRouter`: Router interface
- `IReflexQuoter`: Quoter interface

### Utilities

- `GracefulReentrancyGuard`: Enhanced reentrancy protection
- `DexTypes`: Common type definitions

## TypeScript Integration

```typescript
import { contracts, interfaces, version } from "@lotus-research/reflex";

// Get contract paths
const reflexRouter = contracts.ReflexRouter;
const plugin = contracts.AlgebraBasePluginV3;
const splitter = contracts.FundsSplitter;

console.log(`Using Reflex v${version}`);
```

### Generating TypeScript Types

If you need TypeScript contract types, use TypeChain with your Hardhat setup:

```bash
npm install --save-dev @typechain/ethers-v6 typechain
npx hardhat compile
npx typechain --target ethers-v6 --out-dir typechain-types 'artifacts/**/*.json'
```

## License

MIT
