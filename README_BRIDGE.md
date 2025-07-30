# 1inch Ethereum-Aptos Cross-chain Bridge

A novel extension for 1inch Cross-chain Swap (Fusion+) that enables bidirectional atomic swaps between Ethereum and Aptos blockchains, preserving hashlock and timelock functionality for secure cross-chain transactions.

## 🌟 Features

- **Bidirectional Swaps**: Support for both Ethereum → Aptos and Aptos → Ethereum swaps
- **Atomic Security**: Hashlock/timelock mechanism ensures atomic execution or rollback
- **1inch Integration**: Built upon proven 1inch cross-chain contracts
- **Aptos Native**: Full Move language implementation for Aptos side
- **Production Ready**: Mainnet and testnet execution support
- **TypeScript SDK**: Comprehensive SDK for easy integration

## 🏗️ Architecture

### EVM Side (Ethereum)
- **AptosEthereumResolver.sol**: Enhanced resolver contract supporting Aptos integration
- Built on top of 1inch's proven escrow factory pattern
- Maintains compatibility with existing 1inch infrastructure

### Aptos Side (Move)
- **base_escrow.move**: Core escrow functionality with hashlock/timelock
- **resolver.move**: Cross-chain swap coordination and lifecycle management
- Native Move implementation preserving security guarantees

### SDK
- **TypeScript SDK**: Unified interface for both chains
- **Demo Scripts**: Comprehensive examples for all swap scenarios
- **Error Handling**: Robust error handling and recovery mechanisms

## 📁 Project Structure

```
├── contracts/
│   ├── src/
│   │   ├── AptosEthereumResolver.sol     # Enhanced EVM resolver
│   │   ├── Resolver.sol                  # Original resolver (for reference)
│   │   └── TestEscrowFactory.sol         # Test factory
│   └── lib/                              # 1inch dependencies
├── aptos-contracts/
│   ├── sources/
│   │   ├── base_escrow.move              # Core Aptos escrow
│   │   └── resolver.move                 # Aptos swap resolver
│   └── Move.toml                         # Aptos package config
├── sdk/
│   ├── src/
│   │   └── index.ts                      # TypeScript SDK
│   └── package.json
├── demo/
│   ├── src/
│   │   ├── eth-to-aptos-demo.ts          # ETH→APT demo
│   │   ├── aptos-to-eth-demo.ts          # APT→ETH demo
│   │   └── complete-swap-demo.ts         # Completion demo
│   └── package.json
└── tests/                                # Existing test suite
```

## 🚀 Quick Start

### Prerequisites

- Node.js 18+
- Foundry (for Solidity contracts)
- Aptos CLI (for Move contracts)
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
   
   # Build Aptos contracts
   cd aptos-contracts
   aptos move compile
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
   
   # Aptos Configuration
   APTOS_NODE_URL=https://fullnode.devnet.aptoslabs.com/v1
   APTOS_PRIVATE_KEY=your_aptos_private_key
   ```

### Demo 1: Ethereum to Aptos Swap

```bash
cd demo
npm run demo:eth-to-aptos
```

This demo:
- Generates a secret for the atomic swap
- Creates an Aptos escrow to receive APT
- Creates an Ethereum escrow to lock ETH
- Shows swap metadata and next steps

### Demo 2: Aptos to Ethereum Swap

```bash
cd demo
npm run demo:aptos-to-eth
```

This demo:
- Creates an Aptos escrow to lock APT
- Creates an Ethereum escrow to receive ETH
- Demonstrates reverse direction flow

### Demo 3: Complete Swap

```bash
cd demo
npm run demo:complete-swap [swapId] [secret]
```

This demo:
- Reveals the secret to complete the atomic swap
- Withdraws funds from both escrows
- Shows final swap completion

## 📋 Swap Flow

### Ethereum → Aptos Flow

1. **Initiation**
   - User calls `initiateEthToAptosSwap()` on Ethereum resolver
   - Ethereum escrow locks ETH with hashlock/timelock
   - Aptos escrow created to receive APT

2. **Execution**
   - Taker reveals secret on Aptos side during withdrawal period
   - Secret allows withdrawal of APT from Aptos escrow
   - Same secret can be used to claim ETH from Ethereum escrow

3. **Completion**
   - Both parties receive their funds atomically
   - If secret not revealed, funds return to original owners after timeout

### Aptos → Ethereum Flow

Similar flow but reversed:
1. Aptos escrow locks APT
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
   forge script script/Deploy.s.sol --rpc-url $ETH_RPC_URL --broadcast
   ```

2. **Deploy Aptos contracts**
   ```bash
   cd aptos-contracts
   aptos move publish --profile devnet
   ```

3. **Run integration tests**
   ```bash
   cd demo
   npm run demo:eth-to-aptos
   # Save the output swapId and secret
   npm run demo:complete-swap <swapId> <secret>
   ```

## 🌐 Mainnet Deployment

### Ethereum Mainnet
1. Deploy `AptosEthereumResolver` contract
2. Configure with appropriate timelock parameters
3. Set up monitoring for swap events

### Aptos Mainnet
1. Publish Move packages to mainnet
2. Initialize resolver with proper permissions
3. Configure cross-chain event monitoring

### Production Considerations
- **Gas Optimization**: Optimize contract calls for lower fees
- **Monitoring**: Set up event monitoring for both chains
- **Error Handling**: Implement robust error recovery
- **Rate Limiting**: Consider rate limits for large swaps

## 📚 API Reference

### EthereumAptosSwapSDK

#### `constructor(ethConfig, aptosConfig)`
Initialize the SDK with blockchain configurations.

#### `generateSecret()`
Generate a cryptographically secure secret and its hash.

#### `initiateEthToAptosSwap(params)`
Start an Ethereum to Aptos swap.

#### `initiateAptosToEthSwap(params)`
Start an Aptos to Ethereum swap.

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
| `APTOS_NODE_URL` | Aptos node URL | `https://fullnode.mainnet.aptoslabs.com/v1` |
| `APTOS_PRIVATE_KEY` | Aptos private key | `0x456...` |

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
- [Aptos Core](https://github.com/aptos-labs/aptos-core)

---

**⚠️ Disclaimer**: This is experimental software. Use at your own risk. Always test thoroughly before using with real funds.
