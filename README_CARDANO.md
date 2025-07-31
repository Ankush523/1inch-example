# 1inch Ethereum-Cardano Cross-chain Bridge

A novel extension for 1inch Cross-chain Swap (Fusion+) that enables bidirectional atomic swaps between Ethereum and Cardano blockchains, preserving hashlock and timelock functionality for secure cross-chain transactions.

## 🌟 Features

- **Bidirectional Swaps**: Support for both Ethereum → Cardano and Cardano → Ethereum swaps
- **Atomic Security**: Hashlock/timelock mechanism ensures atomic execution or rollback
- **1inch Integration**: Built upon proven 1inch cross-chain contracts
- **Cardano Native**: Full Plutus/Haskell implementation for Cardano side
- **Production Ready**: Mainnet and testnet execution support
- **TypeScript SDK**: Comprehensive SDK for easy integration

## 🏗️ Architecture

### EVM Side (Ethereum)
- **CardanoEthereumResolver.sol**: Enhanced resolver contract supporting Cardano integration
- Built on top of 1inch's proven escrow factory pattern
- Maintains compatibility with existing 1inch infrastructure

### Cardano Side (Plutus/Haskell)
- **CardanoEscrow.hs**: Core escrow functionality with hashlock/timelock
- **CardanoResolver.hs**: Cross-chain swap coordination and lifecycle management
- Native Plutus implementation preserving security guarantees

### SDK
- **TypeScript SDK**: Unified interface for both chains
- **Demo Scripts**: Comprehensive examples for all swap scenarios
- **Error Handling**: Robust error handling and recovery mechanisms

## 📁 Project Structure

```
├── contracts/
│   ├── src/
│   │   ├── CardanoEthereumResolver.sol     # Enhanced EVM resolver
│   │   └── TestEscrowFactory.sol           # Test factory
│   └── lib/                                # 1inch dependencies
├── cardano-contracts/
│   ├── src/
│   │   ├── CardanoEscrow.hs               # Core Cardano escrow
│   │   └── CardanoResolver.hs             # Cardano swap resolver
│   ├── cardano-cross-chain-swap.cabal     # Cabal package config
│   └── cabal.project                      # Project dependencies
├── sdk/
│   ├── src/
│   │   ├── index.ts                       # TypeScript SDK
│   │   └── cardano-sdk.ts                 # Cardano-specific SDK
│   └── package.json
├── demo/
│   ├── src/
│   │   ├── eth-to-cardano-demo.ts         # ETH→ADA demo
│   │   ├── cardano-to-eth-demo.ts         # ADA→ETH demo
│   │   └── complete-cardano-swap-demo.ts  # Completion demo
│   └── package.json
└── tests/                                 # Test suite
```

## 🚀 Quick Start

### Prerequisites

- Node.js 18+
- Foundry (for Solidity contracts)
- GHC and Cabal (for Cardano contracts)
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd cross-chain-resolver-example
   ```

2. **Install dependencies**
   ```bash
   # Install main project dependencies
   pnpm install
   
   # Install Solidity dependencies
   forge install
   
   # Install SDK dependencies
   cd sdk && npm install && cd ..
   
   # Install demo dependencies
   cd demo && npm install && cd ..
   ```

3. **Build contracts**
   ```bash
   # Build Solidity contracts
   forge build
   
   # Build Cardano contracts
   cd cardano-contracts
   cabal build
   cd ..
   ```

4. **Build SDK and demos**
   ```bash
   cd sdk && npm run build && cd ..
   cd demo && npm run build && cd ..
   ```

## 🧪 Running Demos

The demo scripts showcase the complete cross-chain swap functionality:

### Setup Environment

1. Copy demo environment file:
   ```bash
   cd demo
   cp .env.example .env
   ```

2. Configure your environment variables in `.env`:
   ```env
   # Ethereum Configuration
   ETH_RPC_URL=https://ethereum-sepolia.blockpi.network/v1/rpc/public
   ETH_PRIVATE_KEY=your_private_key
   ETH_RESOLVER_ADDRESS=deployed_resolver_address
   
   # Cardano Configuration
   CARDANO_NODE_URL=https://preprod.cardano-testnet.iohk.io
   CARDANO_PRIVATE_KEY=your_cardano_private_key
   ```

### Demo 1: Ethereum to Cardano Swap

```bash
cd demo
npm run demo:eth-to-cardano
```

This demo:
- Generates a secret for the atomic swap
- Creates a Cardano escrow to receive ADA
- Creates an Ethereum escrow to lock ETH
- Shows swap metadata and next steps

### Demo 2: Cardano to Ethereum Swap

```bash
cd demo
npm run demo:cardano-to-eth
```

This demo:
- Creates a Cardano escrow to lock ADA
- Creates an Ethereum escrow to receive ETH
- Demonstrates reverse direction flow

### Demo 3: Complete Swap

```bash
cd demo
npm run demo:complete-cardano-swap [swapId] [secret]
```

This demo:
- Reveals the secret to complete the atomic swap
- Withdraws funds from both escrows
- Shows final swap completion

## 📋 Swap Flow

### Ethereum → Cardano Flow

1. **Initiation**
   - User calls `initiateEthToCardanoSwap()` on Ethereum resolver
   - Ethereum escrow locks ETH with hashlock/timelock
   - Cardano escrow created to receive ADA

2. **Execution**
   - Taker reveals secret on Cardano side during withdrawal period
   - Secret allows withdrawal of ADA from Cardano escrow
   - Same secret can be used to claim ETH from Ethereum escrow

3. **Completion**
   - Both parties receive their funds atomically
   - If secret not revealed, funds return to original owners after timeout

### Cardano → Ethereum Flow

Similar flow but reversed:
1. Cardano escrow locks ADA
2. Ethereum escrow locks ETH
3. Secret revelation triggers atomic completion

## 🔒 Security Features

### Hashlock Mechanism
- Cryptographic commitment scheme using Keccak256
- Same secret unlocks both escrows
- Prevents double-spending and ensures atomicity

### Timelock Protection
- **Withdrawal Period**: Only taker can withdraw with secret
- **Public Withdrawal**: Anyone can complete with secret (prevents griefing)
- **Cancellation Period**: Maker can cancel and recover funds
- **Emergency Rescue**: Ultimate fallback for fund recovery

### Immutable Parameters
- Order hash, amounts, addresses locked at creation
- Prevents parameter manipulation during swap lifecycle
- Ensures what was agreed is what gets executed

## 🧪 Testing

### Run Existing Tests
```bash
# Set up test environment
SRC_CHAIN_RPC=ETH_FORK_URL DST_CHAIN_RPC=BNB_FORK_URL pnpm test
```

### Deploy and Test Contracts

1. **Deploy Ethereum contracts**
   ```bash
   forge script scripts/DeployCardanoEthereumResolver.s.sol --rpc-url $ETH_RPC_URL --broadcast
   ```

2. **Deploy Cardano contracts**
   ```bash
   cd cardano-contracts
   cabal build
   # In production, this would deploy to Cardano testnet/mainnet
   ```

3. **Run integration tests**
   ```bash
   cd demo
   npm run demo:eth-to-cardano
   # Save the output swapId and secret
   npm run demo:complete-cardano-swap <swapId> <secret>
   ```

## 🌐 Mainnet Deployment

### Ethereum Mainnet
1. Deploy `CardanoEthereumResolver` contract
2. Configure with appropriate timelock parameters
3. Set up monitoring for swap events

### Cardano Mainnet
1. Compile and deploy Plutus contracts to mainnet
2. Initialize resolver with proper permissions
3. Configure cross-chain event monitoring

### Production Considerations
- **Gas Optimization**: Optimize contract calls for lower fees
- **Monitoring**: Set up event monitoring for both chains
- **Error Handling**: Implement robust error recovery
- **Rate Limiting**: Consider rate limits for large swaps

## 📚 API Reference

### CardanoEthereumSwapSDK

#### `constructor(ethConfig, cardanoConfig)`
Initialize the SDK with blockchain configurations.

#### `generateSecret()`
Generate a cryptographically secure secret and its hash.

#### `initiateEthToCardanoSwap(params)`
Start an Ethereum to Cardano swap.

#### `initiateCardanoToEthSwap(params)`
Start a Cardano to Ethereum swap.

#### `completeSwap(swapId, secret)`
Complete a swap by revealing the secret.

#### `cancelSwap(swapId)`
Cancel an active swap (if in cancellation period).

#### `getSwapMetadata(swapId)`
Retrieve current swap status and metadata.

## 🔧 Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `ETH_RPC_URL` | Ethereum RPC endpoint | `https://mainnet.infura.io/v3/...` |
| `ETH_PRIVATE_KEY` | Ethereum private key | `0x123...` |
| `ETH_RESOLVER_ADDRESS` | Deployed resolver address | `0xabc...` |
| `CARDANO_NODE_URL` | Cardano node URL | `https://preprod.cardano-testnet.iohk.io` |
| `CARDANO_PRIVATE_KEY` | Cardano private key | `0x456...` |

### Timelock Configuration

Default timelock parameters (configurable):
- **Withdrawal Start**: 5 minutes after creation
- **Withdrawal End**: 1 hour after creation
- **Cancellation Start**: 1 hour after creation
- **Emergency Rescue**: 24 hours after creation

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.

## 🆘 Support

- **Documentation**: Check this README and code comments
- **Issues**: Open GitHub issues for bugs
- **Discussions**: Use GitHub discussions for questions

## 🔗 Related Projects

- [1inch Cross-chain SDK](https://github.com/1inch/cross-chain-sdk)
- [1inch Limit Order Protocol](https://github.com/1inch/limit-order-protocol)
- [Cardano Plutus](https://github.com/input-output-hk/plutus)

---

**⚠️ Disclaimer**: This is experimental software. Use at your own risk. Always test thoroughly before using with real funds. 