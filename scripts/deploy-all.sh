#!/bin/bash

# Deploy both Ethereum and Aptos contracts
# Usage: ./deploy-all.sh [eth-network] [aptos-profile]

ETH_NETWORK=${1:-sepolia}
APTOS_PROFILE=${2:-devnet}

echo "🌉 Deploying Ethereum-Aptos Cross-chain Bridge"
echo "📍 Ethereum: $ETH_NETWORK"
echo "📍 Aptos: $APTOS_PROFILE"
echo ""

# Check prerequisites
if ! command -v forge &> /dev/null; then
    echo "❌ Foundry not found. Please install: https://book.getfoundry.sh/"
    exit 1
fi

if ! command -v aptos &> /dev/null; then
    echo "❌ Aptos CLI not found. Please install: https://aptos.dev/cli-tools/aptos-cli-tool/install-aptos-cli"
    exit 1
fi

# Deploy Ethereum contracts
echo "🔗 Deploying Ethereum contracts..."

if [ ! -f ".env" ]; then
    echo "❌ .env file not found. Please create one with PRIVATE_KEY"
    exit 1
fi

source .env

if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ PRIVATE_KEY not set in .env"
    exit 1
fi

# Get RPC URL
case $ETH_NETWORK in
    "mainnet")
        RPC_URL=${MAINNET_RPC_URL:-"https://eth.merkle.io"}
        ;;
    "sepolia")
        RPC_URL=${SEPOLIA_RPC_URL:-"https://ethereum-sepolia.blockpi.network/v1/rpc/public"}
        ;;
    "goerli")
        RPC_URL=${GOERLI_RPC_URL:-"https://ethereum-goerli.blockpi.network/v1/rpc/public"}
        ;;
    *)
        RPC_URL=$ETH_NETWORK
        ;;
esac

echo "📡 Using RPC: $RPC_URL"

# Deploy with Forge
forge script scripts/DeployAptosEthereumResolver.s.sol:DeployAptosEthereumResolver \
    --rpc-url $RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key ${ETHERSCAN_API_KEY:-""} \
    -vvvv

if [ $? -ne 0 ]; then
    echo "❌ Ethereum deployment failed"
    exit 1
fi

echo "✅ Ethereum contracts deployed!"
echo ""

# Deploy Aptos contracts
echo "🟠 Deploying Aptos contracts..."
./scripts/deploy-aptos.sh $APTOS_PROFILE

if [ $? -ne 0 ]; then
    echo "❌ Aptos deployment failed"
    exit 1
fi

echo ""
echo "🎉 All contracts deployed successfully!"
echo ""

# Display deployment summary
echo "📋 Deployment Summary:"
echo "====================="

if [ -f "deployment.json" ]; then
    echo "🔗 Ethereum ($ETH_NETWORK):"
    cat deployment.json | jq -r '"  Resolver: " + .resolver + "\n  Factory: " + .factory'
fi

if [ -f "aptos-deployment.json" ]; then
    echo "🟠 Aptos ($APTOS_PROFILE):"
    cat aptos-deployment.json | jq -r '"  Package: " + .package_address'
fi

echo ""
echo "🚀 Next steps:"
echo "1. Update demo/.env with deployed contract addresses"
echo "2. Run demos: cd demo && npm run demo:eth-to-aptos"
echo "3. Test on testnet before mainnet usage"
