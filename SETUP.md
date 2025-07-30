# Environment Setup for Cross-Chain Deployment

This guide will help you set up your environment to deploy contracts and execute cross-chain swaps.

## Prerequisites

1. **Install Aptos CLI**:
   ```bash
   brew install aptos
   ```

2. **Install dependencies**:
   ```bash
   npm install
   ```

## Environment Variables Setup

Create a `.env` file in the project root with the following variables:

```bash
# Ethereum Testnet Configuration
ETH_TESTNET_RPC=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
DEPLOYER_PRIVATE_KEY=0x... # Your Ethereum private key (with testnet ETH)

# Aptos Testnet Configuration  
APTOS_TESTNET_ACCOUNT=0x... # Your Aptos account address
APTOS_PRIVATE_KEY=0x... # Your Aptos private key
```

## Getting Testnet Credentials

### Ethereum Sepolia Testnet

1. **Get an Infura API key**:
   - Visit [infura.io](https://infura.io)
   - Create account and project
   - Copy your project ID for `ETH_TESTNET_RPC`

2. **Create a wallet and get testnet ETH**:
   - Use MetaMask or generate a new wallet
   - Add Sepolia testnet to MetaMask
   - Get testnet ETH from [Sepolia Faucet](https://sepoliafaucet.com/)
   - Export private key for `DEPLOYER_PRIVATE_KEY`

### Aptos Testnet

1. **Initialize Aptos account**:
   ```bash
   aptos init --profile testnet --network testnet
   ```

2. **Fund your account**:
   ```bash
   aptos account fund-with-faucet --profile testnet
   ```

3. **Get your credentials**:
   - Your account address will be shown after `aptos init`
   - Private key is in `~/.aptos/config.yaml`
   - Copy both to your `.env` file

## Running the Script

Once your environment is set up:

```bash
npm run deploy-and-swap
```

This will:
1. ✅ Deploy EVM contracts to Sepolia
2. ✅ Deploy Aptos contracts to testnet
3. ✅ Execute a complete ETH → APTOS cross-chain swap
4. ✅ Save deployment info to a JSON file

## Verification

After running the script, you can verify:

1. **Ethereum contracts**: Check on [Sepolia Etherscan](https://sepolia.etherscan.io)
2. **Aptos contracts**: Check on [Aptos Explorer](https://explorer.aptoslabs.com/?network=testnet)
3. **Swap transactions**: Transaction hashes will be displayed in the console

## Troubleshooting

### Common Issues

1. **"Insufficient ETH balance"**:
   - Get more testnet ETH from faucet
   - Make sure you're using Sepolia testnet

2. **"Aptos CLI not found"**:
   - Install with `brew install aptos`
   - Restart terminal

3. **"Account funding failed"**:
   - Try manually: `aptos account fund-with-faucet --account YOUR_ADDRESS --url https://fullnode.testnet.aptoslabs.com/v1`

4. **"Move compilation failed"**:
   - Make sure you're in the right directory
   - Try: `cd aptos-contracts && aptos move compile --dev`

### Environment Variables Check

You can test your setup with:
```bash
npm test -- tests/ethereum-aptos-bridge.spec.ts
```

This test will show exactly what's missing from your environment.

## Security Notes

⚠️ **Important**: Never commit your private keys to version control!

- Use testnet accounts only
- Keep your `.env` file local
- Consider using hardware wallets for mainnet
