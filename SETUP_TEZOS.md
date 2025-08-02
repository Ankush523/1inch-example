# Tezos Setup Guide

## Overview

This guide will help you set up and test the ETH<>Tezos cross-chain atomic swap bridge in **under 10 minutes**.

## Prerequisites

Before starting, ensure you have:

- [x] **Node.js** >= 18.0.0 installed
- [x] **Git** for cloning the repository  
- [x] **Metamask** or similar wallet with ETH on Sepolia testnet
- [x] **Tezos wallet** with XTZ on Ghostnet (optional for full testing)

## Installation
- [x] **Tezos wallet** with XTZ on Ghostnet (optional for full testing)

## Step 1: Clone & Install (2 minutes)

```bash
# Clone the repository
git clone https://github.com/Ankush523/1inch-example.git
cd 1inch-example

# Install dependencies
npm install
cd sdk && npm install @taquito/taquito @taquito/signer
cd ../demo && npm install
cd ..
```

## Step 2: Configure Environment (1 minute)

```bash
# Copy environment template
cp demo/.env.example demo/.env

# Edit the .env file with your details
nano demo/.env
```

**Required configuration:**
```bash
# Your Ethereum RPC URL (get free from Alchemy/Infura)
ETH_TESTNET_RPC=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY

# Your wallet private key (for testing only!)
DEPLOYER_PRIVATE_KEY=0x...

# Existing contract addresses (already configured)
FACTORY_ADDRESS=0x218fbA453A0d51D86a8deA1d359D965CC4873A5c
LIMIT_ORDER_PROTOCOL_ADDRESS=0x11431eE90fE1414c314026d4600A0aC1D85F5F98
```

## Step 3: Deploy Ethereum Contract (2 minutes)

```bash
# Deploy the TezosEthereumResolver contract
npm run deploy:tezos

# Or manually:
forge script scripts/DeployTezosEthereumResolver.s.sol \
  --rpc-url $ETH_TESTNET_RPC \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --broadcast
```

**Expected output:**
```
TezosEthereumResolver deployed at: 0x...
```

Update your `.env` file:
```bash
TEZOS_RESOLVER_ADDRESS=0x... # The deployed address
```

## Step 4: Test the Bridge (1 minute)

```bash
# Test if everything is configured correctly
npm run test:tezos-bridge

# Expected output:
# ✅ Ethereum connection: Working
# ✅ TezosResolver deployment: Verified
# ⚠️ Tezos configuration: Incomplete (expected)
```

## Step 5: Optional - Deploy Tezos Contracts (3 minutes)

**If you want full Tezos integration:**

```bash
# Install Tezos client (Ubuntu/Debian)
sudo apt-get install tezos-client

# Or macOS
brew tap serokell/tezos-packaging-stable
brew install tezos-client

# Deploy Tezos contracts
npm run deploy:tezos-contracts

# This will:
# 1. Create a test wallet
# 2. Guide you to get test XTZ
# 3. Deploy escrow and resolver contracts
```

## Step 6: Run Your First Swap Demo (1 minute)

```bash
# Run ETH to Tezos demo (simulation)
npm run demo:eth-to-tezos

# Expected output:
# 🚀 ETH to Tezos Cross-Chain Swap Demo
# ✅ Swap initiated successfully!
# Transaction Hash: 0x...
# Swap ID: 0x...
```

## 🎉 You're Ready!

Your ETH<>Tezos bridge is now set up and ready for testing!

## Quick Commands Reference

```bash
# Deploy contracts
npm run deploy:eth-tezos          # Deploy everything
npm run deploy:tezos              # Ethereum only
npm run deploy:tezos-contracts    # Tezos only

# Test the bridge
npm run test:tezos-bridge         # Configuration test

# Run demos
npm run demo:eth-to-tezos         # ETH → Tezos swap
npm run demo:tezos-to-eth         # Tezos → ETH swap  
npm run demo:complete-tezos-swap  # Complete a swap

# Build everything
npm run build                     # Build all components
```

## What You Can Do Now

### 🧪 **Testing & Development**
- Run swap simulations between ETH and Tezos
- Test atomic swap mechanics with timelocks
- Experiment with different swap amounts

### 🔧 **Customization** 
- Modify timelock periods in contracts
- Add custom token support
- Integrate with your own UI

### 🚀 **Production Ready**
- Deploy to mainnets (after auditing)
- Integrate with your dApp
- Build a full bridge interface

## Troubleshooting

### ❌ **Deployment Fails**
```bash
# Check your configuration
cat demo/.env

# Verify account has ETH
# Get free Sepolia ETH: https://sepoliafaucet.com
```

### ❌ **RPC Issues**
```bash
# Try different RPC endpoints:
# Alchemy: https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
# Infura: https://sepolia.infura.io/v3/YOUR_KEY
# Public: https://ethereum-sepolia.blockpi.network/v1/rpc/public
```

### ❌ **Tezos Client Issues**
```bash
# Check installation
tezos-client --version

# Configure network
tezos-client --endpoint https://ghostnet.tezos.marigold.dev config update
```

## Next Steps

1. **Read the full documentation**: `README_TEZOS.md`
2. **Explore the code**: 
   - Ethereum: `contracts/src/TezosEthereumResolver.sol`
   - Tezos: `tezos-contracts/`
   - SDK: `sdk/src/tezos-sdk.ts`
3. **Run integration tests**: `tests/`
4. **Build your own UI**: Use the SDK as a foundation

## Support

- 🐛 **Issues**: Create a GitHub issue
- 📖 **Documentation**: See `README_TEZOS.md`
- 💬 **Questions**: Check existing issues or discussions

---

**⚠️ Security Notice**: This is for testnet use only. Audit thoroughly before mainnet deployment.

**🎯 Goal Achieved**: You now have a working ETH<>Tezos atomic swap bridge!
