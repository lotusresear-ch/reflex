/**
 * @title Lotus Reflex
 * @description MEV capture engine for Algebra-based DEX protocols
 * @author Lotus Research
 * @license MIT
 */

// Contract paths for easy import in other projects
export const contracts = {
  ReflexRouter: "./src/ReflexRouter.sol",
  ReflexAfterSwap: "./src/integrations/ReflexAfterSwap.sol",
  AlgebraBasePluginV3:
    "./src/integrations/algebra/full/AlgebraBasePluginV3.sol",
  FundsSplitter: "./src/integrations/FundsSplitter/FundsSplitter.sol",
  GracefulReentrancyGuard: "./src/utils/GracefulReentrancyGuard.sol",
} as const;

// Interface paths
export const interfaces = {
  IReflexRouter: "./src/interfaces/IReflexRouter.sol",
  IReflexQuoter: "./src/interfaces/IReflexQuoter.sol",
} as const;

// Library paths
export const libraries = {
  DexTypes: "./src/libraries/DexTypes.sol",
} as const;

// Export all contract paths for convenience
export const allContracts = {
  ...contracts,
  ...interfaces,
  ...libraries,
} as const;

// Version information
export const version = "1.0.0";

// Helper function to get contract source path
export function getContractPath(
  contractName: keyof typeof allContracts
): string {
  return allContracts[contractName];
}

// Note: For TypeScript type generation, users should use TypeChain with their own Hardhat setup
// This package focuses on providing the Solidity source code for easy integration
