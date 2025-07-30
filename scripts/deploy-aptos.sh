#!/bin/bash

# Deploy Aptos contracts to devnet
# Usage: ./deploy-aptos.sh [profile]

PROFILE=${1:-devnet}

echo "🚀 Deploying Aptos contracts to $PROFILE..."

cd aptos-contracts

# Check if profile exists
if ! aptos config show-profiles | grep -q "$PROFILE"; then
    echo "❌ Profile '$PROFILE' not found. Creating..."
    read -p "Enter your private key: " PRIVATE_KEY
    read -p "Enter node URL (default: https://fullnode.devnet.aptoslabs.com/v1): " NODE_URL
    NODE_URL=${NODE_URL:-"https://fullnode.devnet.aptoslabs.com/v1"}
    
    aptos init --profile $PROFILE --private-key $PRIVATE_KEY --rest-url $NODE_URL --skip-faucet
fi

# Compile contracts
echo "📦 Compiling contracts..."
aptos move compile --profile $PROFILE

if [ $? -ne 0 ]; then
    echo "❌ Compilation failed"
    exit 1
fi

# Fund account if on devnet
if [ "$PROFILE" = "devnet" ]; then
    echo "💰 Funding account on devnet..."
    aptos account fund-with-faucet --profile $PROFILE || echo "⚠️  Faucet funding failed, continuing..."
fi

# Publish contracts
echo "🚀 Publishing contracts..."
aptos move publish --profile $PROFILE --assume-yes

if [ $? -eq 0 ]; then
    echo "✅ Contracts deployed successfully!"
    
    # Get account address
    ACCOUNT=$(aptos config show-profiles --profile $PROFILE | grep "account" | awk '{print $2}')
    
    # Save deployment info
    cat > ../aptos-deployment.json << EOF
{
  "profile": "$PROFILE",
  "account": "$ACCOUNT",
  "package_address": "$ACCOUNT",
  "modules": [
    "base_escrow",
    "resolver"
  ],
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    echo "📄 Deployment info saved to aptos-deployment.json"
    echo "📦 Package address: $ACCOUNT"
    
else
    echo "❌ Deployment failed"
    exit 1
fi

cd ..

echo "🎉 Aptos deployment complete!"
