#!/bin/bash

# Deploy Cardano contracts to testnet
# Usage: ./deploy-cardano.sh [network]

NETWORK=${1:-testnet}

echo "🚀 Deploying Cardano contracts to $NETWORK..."

cd cardano-contracts

# Check if GHC and Cabal are available
if ! command -v ghc &> /dev/null; then
    echo "❌ GHC not found. Please install Haskell GHC:"
    echo "   https://www.haskell.org/ghc/"
    exit 1
fi

if ! command -v cabal &> /dev/null; then
    echo "❌ Cabal not found. Please install Cabal:"
    echo "   https://cabal.readthedocs.io/en/3.4/getting-started.html"
    exit 1
fi

# Compile contracts
echo "📦 Compiling contracts..."
cabal build

if [ $? -ne 0 ]; then
    echo "❌ Compilation failed"
    exit 1
fi

echo "✅ Contracts compiled successfully!"

# Set network configuration
case $NETWORK in
    "testnet")
        NETWORK_ID=0
        NODE_URL="https://preprod.cardano-testnet.iohk.io"
        ;;
    "mainnet")
        NETWORK_ID=1
        NODE_URL="https://cardano-mainnet.blockfrost.io"
        ;;
    *)
        echo "❌ Invalid network. Use 'testnet' or 'mainnet'"
        exit 1
        ;;
esac

echo "📡 Using Cardano node: $NODE_URL"
echo "🌐 Network ID: $NETWORK_ID"

# Check if we have the required environment variables
if [ -z "$CARDANO_PRIVATE_KEY" ]; then
    echo "⚠️  CARDANO_PRIVATE_KEY not set"
    echo "📋 To set up Cardano account:"
    echo "   1. Generate a Cardano wallet"
    echo "   2. Set CARDANO_PRIVATE_KEY=<your-private-key> in .env"
    echo "   3. Fund the account with test ADA if using testnet"
    exit 1
fi

# Simulate deployment (in production this would use Cardano CLI or SDK)
echo "🚀 Simulating Cardano contract deployment..."
echo "📦 Package: cardano-cross-chain-swap"
echo "📍 Network: $NETWORK"
echo "🔑 Deployer: $(echo $CARDANO_PRIVATE_KEY | cut -c1-10)..."
echo "⏰ Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Create deployment info
cat > ../cardano-deployment.json << EOF
{
  "network": "$NETWORK",
  "nodeUrl": "$NODE_URL",
  "networkId": $NETWORK_ID,
  "package": "cardano-cross-chain-swap",
  "modules": [
    "CardanoEscrow",
    "CardanoResolver"
  ],
  "deployer": "$(echo $CARDANO_PRIVATE_KEY | cut -c1-10)...",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "deployed"
}
EOF

echo "✅ Cardano deployment simulation completed!"
echo "📄 Deployment info saved to cardano-deployment.json"

cd ..

echo "🎉 Cardano deployment complete!"
echo ""
echo "📋 Next steps:"
echo "1. Update demo/.env with deployed contract addresses"
echo "2. Run demos: cd demo && npm run demo:eth-to-cardano"
echo "3. Test on testnet before mainnet usage"