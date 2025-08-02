#!/bin/bash

# Deploy Tezos contracts for ETH<>Tezos cross-chain swaps
# This script deploys the Tezos escrow and resolver contracts

set -e

echo "🚀 Deploying Tezos Contracts for ETH<>Tezos Bridge"
echo "================================================"

# Load environment variables
if [ -f .env ]; then
    source .env
fi

# Configuration
TEZOS_RPC=${TEZOS_RPC_URL:-"https://ghostnet.tezos.marigold.dev"}
TEZOS_CLIENT_DIR=${TEZOS_CLIENT_DIR:-"$HOME/.tezos-client"}

echo "Configuration:"
echo "- Tezos RPC: $TEZOS_RPC"
echo "- Client Dir: $TEZOS_CLIENT_DIR"
echo ""

# Check if tezos-client is installed
if ! command -v tezos-client &> /dev/null; then
    echo "❌ tezos-client is not installed"
    echo "Please install Tezos client:"
    echo "https://tezos.gitlab.io/introduction/howtoget.html"
    exit 1
fi

# Configure tezos-client
echo "📋 Configuring tezos-client..."
tezos-client --endpoint $TEZOS_RPC config update

# Check if wallet exists
if ! tezos-client list known addresses | grep -q "alice"; then
    echo "📱 Creating test wallet..."
    # Generate a new key for testing
    tezos-client gen keys alice
    
    echo "🔑 Getting test funds..."
    ALICE_ADDRESS=$(tezos-client show address alice | grep Hash | cut -d' ' -f2)
    echo "Alice address: $ALICE_ADDRESS"
    echo "Please visit the Tezos faucet to get test XTZ:"
    echo "https://faucet.ghostnet.tezos.co/"
    echo "Send some XTZ to: $ALICE_ADDRESS"
    echo ""
    read -p "Press Enter when you have funded the address..."
fi

# Check balance
echo "💰 Checking balance..."
ALICE_BALANCE=$(tezos-client get balance for alice)
echo "Alice balance: $ALICE_BALANCE"

if [ "$ALICE_BALANCE" = "0 ꜩ" ]; then
    echo "❌ Alice has no balance. Please fund the address first."
    exit 1
fi

# Deploy escrow contract
echo "📦 Deploying Tezos escrow contract..."
ESCROW_DEPLOY_OUTPUT=$(tezos-client originate contract tezos_escrow \
    transferring 0 from alice \
    running tezos-contracts/tezos_escrow.tz \
    --init '(Pair None False)' \
    --burn-cap 2 2>&1)

echo "$ESCROW_DEPLOY_OUTPUT"

# Extract escrow contract address
ESCROW_ADDRESS=$(echo "$ESCROW_DEPLOY_OUTPUT" | grep "New contract" | sed 's/.*New contract \([^ ]*\) .*/\1/')

if [ -z "$ESCROW_ADDRESS" ]; then
    echo "❌ Failed to deploy escrow contract"
    exit 1
fi

echo "✅ Escrow contract deployed at: $ESCROW_ADDRESS"

# Deploy resolver contract
echo "📦 Deploying Tezos resolver contract..."
RESOLVER_DEPLOY_OUTPUT=$(tezos-client originate contract tezos_resolver \
    transferring 0 from alice \
    running tezos-contracts/tezos_resolver.tz \
    --init '{}' \
    --burn-cap 2 2>&1)

echo "$RESOLVER_DEPLOY_OUTPUT"

# Extract resolver contract address
RESOLVER_ADDRESS=$(echo "$RESOLVER_DEPLOY_OUTPUT" | grep "New contract" | sed 's/.*New contract \([^ ]*\) .*/\1/')

if [ -z "$RESOLVER_ADDRESS" ]; then
    echo "❌ Failed to deploy resolver contract"
    exit 1
fi

echo "✅ Resolver contract deployed at: $RESOLVER_ADDRESS"

# Save deployment information
DEPLOYMENT_FILE="deployment-tezos-ghostnet.json"
cat > $DEPLOYMENT_FILE << EOF
{
  "network": "ghostnet",
  "rpc": "$TEZOS_RPC",
  "deployer": "$(tezos-client show address alice | grep Hash | cut -d' ' -f2)",
  "contracts": {
    "escrow": "$ESCROW_ADDRESS",
    "resolver": "$RESOLVER_ADDRESS"
  },
  "deployedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "blockLevel": "$(tezos-client rpc get /chains/main/blocks/head/header | jq '.level')"
}
EOF

echo ""
echo "🎉 Deployment completed successfully!"
echo "======================================"
echo "Escrow Contract: $ESCROW_ADDRESS"
echo "Resolver Contract: $RESOLVER_ADDRESS"
echo "Deployment info saved to: $DEPLOYMENT_FILE"
echo ""
echo "📝 Next steps:"
echo "1. Update your .env file with these addresses:"
echo "   TEZOS_ESCROW_ADDRESS=$ESCROW_ADDRESS"
echo "   TEZOS_RESOLVER_ADDRESS_TZ=$RESOLVER_ADDRESS"
echo "2. Deploy the Ethereum TezosResolver contract"
echo "3. Test the cross-chain swap functionality"
