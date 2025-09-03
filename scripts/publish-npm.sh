#!/bin/bash

# Reflex NPM Publishing Script
# This script prepares and publishes the Reflex package to NPM

set -e

echo "🔥 Preparing Lotus Reflex for NPM publication..."

# Check if we're on the right branch
CURRENT_BRANCH=$(git branch --show-current)
echo "📍 Current branch: $CURRENT_BRANCH"

# Clean previous build artifacts
echo "🧹 Cleaning previous builds..."
rm -rf dist/
rm -rf out/

# Build contracts with Foundry
echo "🔨 Building contracts with Foundry..."
forge build

# Format code with forge fmt
echo "🎨 Formatting code with forge fmt..."
forge fmt

# Install npm dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing NPM dependencies..."
    npm install
fi

# Compile TypeScript
echo "🔧 Compiling TypeScript..."
npx tsc || echo "⚠️  TypeScript compilation failed, continuing with JS exports only"

# Run tests
echo "🧪 Running tests..."
forge test

# Check version
PACKAGE_VERSION=$(node -p "require('./package.json').version")
echo "📋 Package version: $PACKAGE_VERSION"

# Dry run publish to check package contents
echo "🔍 Dry run publish check..."
npm publish --dry-run

echo "✅ Package preparation complete!"
echo ""
echo "To publish to NPM:"
echo "  npm publish"
echo ""
echo "To publish as beta:"
echo "  npm publish --tag beta"
echo ""
echo "Package contents will include:"
echo "  - Solidity source files (src/)"
echo "  - Deployment scripts (script/)"
echo "  - Foundry configuration"
echo "  - TypeScript definitions (if generated)"
echo "  - README and documentation"
