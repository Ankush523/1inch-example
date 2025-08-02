#!/bin/bash

# Complete deployment script for ETH<>Tezos cross-chain bridge
# This script deploys both Ethereum and Tezos contracts

set -e

echo "🚀 ETH<>Tezos Cross-Chain Bridge Deployment"
echo "==========================================="

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "❌ .env file not found. Please create one based on .env.example"
    exit 1
fi

# Validate required environment variables
REQUIRED_VARS=(
    "ETH_TESTNET_RPC"
    "DEPLOYER_PRIVATE_KEY" 
    "FACTORY_ADDRESS"
    "LIMIT_ORDER_PROTOCOL_ADDRESS"
)

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "❌ Required environment variable $var is not set"
        exit 1
    fi
done

echo "✅ Environment variables validated"
echo ""

# Step 1: Deploy Ethereum TezosResolver
echo "Step 1: Deploying Ethereum TezosResolver..."
echo "============================================"

forge script scripts/DeployTezosEthereumResolver.s.sol \
    --rpc-url $ETH_TESTNET_RPC \
    --private-key $DEPLOYER_PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY || true

if [ -f "deployment-tezos-testnet.json" ]; then
    TEZOS_RESOLVER_ETH=$(jq -r '.tezosResolver' deployment-tezos-testnet.json)
    echo "✅ TezosResolver deployed at: $TEZOS_RESOLVER_ETH"
else
    echo "❌ Failed to deploy TezosResolver"
    exit 1
fi

echo ""

# Step 2: Deploy Tezos contracts
echo "Step 2: Deploying Tezos contracts..."
echo "===================================="

# Check if Tezos client is available
if command -v tezos-client &> /dev/null; then
    ./scripts/deploy-tezos.sh
    
    if [ -f "deployment-tezos-ghostnet.json" ]; then
        TEZOS_ESCROW=$(jq -r '.contracts.escrow' deployment-tezos-ghostnet.json)
        TEZOS_RESOLVER=$(jq -r '.contracts.resolver' deployment-tezos-ghostnet.json)
        echo "✅ Tezos contracts deployed:"
        echo "   Escrow: $TEZOS_ESCROW"
        echo "   Resolver: $TEZOS_RESOLVER"
    else
        echo "❌ Failed to deploy Tezos contracts"
    fi
else
    echo "⚠️ Tezos client not found. Skipping Tezos deployment."
    echo "Please install tezos-client and run: ./scripts/deploy-tezos.sh"
    TEZOS_ESCROW="TO_BE_DEPLOYED"
    TEZOS_RESOLVER="TO_BE_DEPLOYED"
fi

echo ""

# Step 3: Create complete deployment summary
echo "Step 3: Creating deployment summary..."
echo "======================================"

DEPLOYMENT_SUMMARY="deployment-eth-tezos-complete.json"
cat > $DEPLOYMENT_SUMMARY << EOF
{
  "bridge": "ETH<>Tezos",
  "deployedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "networks": {
    "ethereum": {
      "network": "sepolia",
      "rpc": "$ETH_TESTNET_RPC",
      "chainId": 11155111,
      "contracts": {
        "factory": "$FACTORY_ADDRESS",
        "limitOrderProtocol": "$LIMIT_ORDER_PROTOCOL_ADDRESS",
        "tezosResolver": "$TEZOS_RESOLVER_ETH"
      }
    },
    "tezos": {
      "network": "ghostnet",
      "rpc": "${TEZOS_RPC_URL:-https://ghostnet.tezos.marigold.dev}",
      "contracts": {
        "escrow": "$TEZOS_ESCROW",
        "resolver": "$TEZOS_RESOLVER"
      }
    }
  },
  "configuration": {
    "safetyDeposit": "0.01 ETH",
    "timelock": {
      "ethereum": 7200,
      "tezos": 86400
    },
    "limits": {
      "minEth": "0.001",
      "maxEth": "10",
      "minXtz": "1",
      "maxXtz": "1000"
    }
  }
}
EOF

echo "✅ Complete deployment summary saved to: $DEPLOYMENT_SUMMARY"
echo ""

# Step 4: Update environment configuration
echo "Step 4: Updating environment configuration..."
echo "=============================================="

ENV_UPDATE_FILE=".env.tezos"
cat > $ENV_UPDATE_FILE << EOF
# ETH<>Tezos Bridge Configuration
# Copy these values to your .env file

# Ethereum Configuration
ETH_TESTNET_RPC=$ETH_TESTNET_RPC
TEZOS_RESOLVER_ADDRESS=$TEZOS_RESOLVER_ETH

# Tezos Configuration
TEZOS_RPC_URL=${TEZOS_RPC_URL:-https://ghostnet.tezos.marigold.dev}
TEZOS_ESCROW_ADDRESS=$TEZOS_ESCROW
TEZOS_RESOLVER_ADDRESS_TZ=$TEZOS_RESOLVER

# Contract Addresses
FACTORY_ADDRESS=$FACTORY_ADDRESS
LIMIT_ORDER_PROTOCOL_ADDRESS=$LIMIT_ORDER_PROTOCOL_ADDRESS
EOF

echo "✅ Environment configuration saved to: $ENV_UPDATE_FILE"
echo ""

# Step 5: Install required dependencies
echo "Step 5: Installing Tezos SDK dependencies..."
echo "============================================="

cd sdk
npm install @taquito/taquito @taquito/signer
cd ..

echo "✅ Dependencies installed"
echo ""

# Final summary
echo "🎉 Deployment Complete!"
echo "======================="
echo ""
echo "📋 Summary:"
echo "- Ethereum TezosResolver: $TEZOS_RESOLVER_ETH"
echo "- Tezos Escrow: $TEZOS_ESCROW"
echo "- Tezos Resolver: $TEZOS_RESOLVER"
echo ""
echo "📝 Next Steps:"
echo "1. Copy values from $ENV_UPDATE_FILE to your .env file"
echo "2. Test the bridge functionality:"
echo "   cd demo"
echo "   npx ts-node src/eth-to-tezos-demo.ts"
echo "3. Try a complete swap:"
echo "   npx ts-node src/complete-tezos-swap-demo.ts"
echo ""
echo "📚 Documentation:"
echo "- Config: bridge-integration-config-tezos.json"
echo "- Deployment: $DEPLOYMENT_SUMMARY"
echo "- Environment: $ENV_UPDATE_FILE"
