# Ethereum ↔ Tezos Cross-Chain Bridge

This implementation provides atomic swap functionality between Ethereum and Tezos using the 1inch Limit Order Protocol on the Ethereum side and native Tezos smart contracts.

## Overview

This bridge enables atomic swaps between Ethereum and Tezos blockchains, ensuring secure and trustless cross-chain token exchanges.

## Architecture

The system consists of smart contracts on both Ethereum and Tezos that work together to facilitate atomic swaps.

## Architecture Overview

### Ethereum Side
- **TezosEthereumResolver**: Main bridge contract that coordinates swaps
- **EscrowFactory**: Creates escrow contracts for holding ETH during swaps
- **1inch LOP Integration**: Uses 1inch Limit Order Protocol for actual token transfers

### Tezos Side
- **Tezos Escrow Contract**: Holds XTZ during atomic swaps
- **Tezos Resolver Contract**: Manages swap metadata and coordination

## Features

✅ **Atomic Swaps**: Guaranteed exchange or full refund
✅ **Timelock Security**: Protection against non-completion
✅ **1inch Integration**: Real token transfers using 1inch protocol
✅ **Multi-directional**: Both ETH→Tezos and Tezos→ETH
✅ **Testnet Support**: Full testing on Sepolia and Ghostnet

## Quick Start

### Prerequisites

1. **Node.js** >= 18.0.0
2. **Tezos Client** for Tezos contract deployment
3. **Forge** for Ethereum contract deployment
4. **Test funds** on both Ethereum Sepolia and Tezos Ghostnet

### Installation

1. **Install dependencies:**
```bash
npm install
cd sdk && npm install
cd ../demo && npm install
```

2. **Configure environment:**
```bash
cp demo/.env.example demo/.env
# Edit .env with your configuration
```

3. **Deploy contracts:**
```bash
# Deploy everything (Ethereum + Tezos)
npm run deploy:eth-tezos
./scripts/deploy-eth-tezos.sh

# Or deploy separately:
# Ethereum only:
npm run deploy:tezos
forge script scripts/DeployTezosEthereumResolver.s.sol --rpc-url $ETH_TESTNET_RPC --private-key $DEPLOYER_PRIVATE_KEY --broadcast

# Tezos only:
npm run deploy:tezos-contracts
./scripts/deploy-tezos.sh
```

### Testing

```bash
cd demo

# Test bridge configuration
npx ts-node src/test-eth-tezos-bridge.ts

# Run ETH to Tezos demo
npm run demo:eth-to-tezos
npx ts-node src/eth-to-tezos-demo.ts

# Run Tezos to ETH demo
npm run demo:tezos-to-eth
npx ts-node src/tezos-to-eth-demo.ts

# Complete a swap
npm run demo:complete-tezos-swap
npx ts-node src/complete-tezos-swap-demo.ts
```

## Configuration

### Environment Variables

```bash
# Ethereum Configuration
ETH_TESTNET_RPC=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
DEPLOYER_PRIVATE_KEY=0x...
TEZOS_RESOLVER_ADDRESS=0x...

# Tezos Configuration  
TEZOS_RPC_URL=https://ghostnet.tezos.marigold.dev
TEZOS_PRIVATE_KEY=edsk...
TEZOS_ESCROW_ADDRESS=KT1...
TEZOS_RESOLVER_ADDRESS_TZ=KT1...

# Contract Addresses
FACTORY_ADDRESS=0x218fbA453A0d51D86a8deA1d359D965CC4873A5c
LIMIT_ORDER_PROTOCOL_ADDRESS=0x11431eE90fE1414c314026d4600A0aC1D85F5F98
```

## Swap Process

### ETH → Tezos Swap

1. **Initiate**: User calls `initiateEthToTezosSwap()` on Ethereum
2. **Lock ETH**: ETH is locked in escrow contract via 1inch LOP
3. **Create Tezos Escrow**: Corresponding escrow created on Tezos
4. **Lock XTZ**: Counterparty locks XTZ in Tezos escrow
5. **Reveal Secret**: Either party reveals secret to claim funds
6. **Complete**: Both parties receive their respective tokens

### Tezos → ETH Swap

1. **Lock XTZ**: User locks XTZ in Tezos escrow
2. **Create ETH Escrow**: Corresponding escrow created on Ethereum
3. **Lock ETH**: Counterparty locks ETH via 1inch LOP
4. **Reveal Secret**: Either party reveals secret to claim funds
5. **Complete**: Both parties receive their respective tokens

## Security Features

### Timelock Protection
- **Ethereum**: 2-6 hour timelocks for different operations
- **Tezos**: 24-hour timelock for safety
- **Refund Mechanism**: Automatic refund if swap not completed

### Secret Hash Security
- **256-bit secrets** for maximum security
- **SHA256 hashing** for secret verification
- **Atomic revelation** ensures fair exchange

### Multi-layer Validation
- **Address format validation** for both chains
- **Amount validation** and limits
- **Status tracking** prevents double-spending

## API Reference

### TezosEthereumBridgeSDK

```typescript
import { TezosEthereumBridgeSDK } from './sdk/src/tezos-sdk'

const sdk = new TezosEthereumBridgeSDK(
    tezosRpc,
    tezosPrivateKey,
    ethRpc,
    ethPrivateKey,
    resolverAddress,
    tezosEscrowAddress,
    tezosResolverAddress
)

// Initiate swaps
await sdk.initiateEthToTezosSwap(params)
await sdk.initiateTezosToEthSwap(params)

// Complete swaps
await sdk.completeEthToTezosSwap(swapId, secret)
await sdk.completeTezosToEthSwap(swapId, secret)

// Utility functions
await sdk.getSwapDetails(swapId)
await sdk.redeemTezosEscrow(secret)
await sdk.refundTezosEscrow()
```

### Smart Contract Functions

#### TezosEthereumResolver.sol

```solidity
// Initiate swaps
function initiateEthToTezosSwap(...)
function initiateTezosToEthSwap(...)

// Complete swaps
function completeEthToTezosSwap(bytes32 swapId, bytes32 secret)
function completeTezosToEthSwap(bytes32 swapId, bytes32 secret)

// Utility
function getTezosSwapData(bytes32 swapId)
function getAllTezosSwaps()
```

## Deployment Addresses

### Ethereum Sepolia
- **TezosResolver**: `0x...` (Deploy via script)
- **Factory**: `0x218fbA453A0d51D86a8deA1d359D965CC4873A5c`
- **LOP**: `0x11431eE90fE1414c314026d4600A0aC1D85F5F98`

### Tezos Ghostnet
- **Escrow**: `KT1...` (Deploy via script)
- **Resolver**: `KT1...` (Deploy via script)

## Troubleshooting

### Common Issues

1. **Deployment Fails**
   - Check gas price and limits
   - Verify account has sufficient funds
   - Ensure environment variables are set

2. **Swap Initiation Fails**
   - Verify contract addresses
   - Check allowances for ERC-20 tokens
   - Ensure sufficient balance + safety deposit

3. **Tezos Client Issues**
   - Install latest Tezos client
   - Configure correct network endpoint
   - Check account is funded

### Support

- **Issues**: Create GitHub issue with detailed logs
- **Documentation**: See `bridge-integration-config-tezos.json`
- **Examples**: Check `demo/src/` directory

## Development

### Adding New Features

1. **Ethereum Contract**: Modify `TezosEthereumResolver.sol`
2. **Tezos Contract**: Update `tezos_escrow.tz` or `tezos_resolver.tz`
3. **SDK**: Extend `TezosEthereumBridgeSDK` class
4. **Tests**: Add demos in `demo/src/`

### Testing Framework

```bash
# Unit tests
npm test

# Integration tests
cd demo && npm test

# Manual testing
npx ts-node src/test-eth-tezos-bridge.ts
```

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create feature branch
3. Add tests for new functionality
4. Submit pull request with detailed description

---

**⚠️ Important**: This is testnet implementation. Do not use with mainnet funds without thorough auditing.
