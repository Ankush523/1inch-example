import 'dotenv/config';

// Mock SDK for demo purposes
class MockEthereumAptosSwapSDK {
  constructor(ethConfig: any, aptosConfig: any) {
    console.log('📡 SDK initialized for swap completion');
  }

  async completeSwap(swapId: string, secret: string) {
    console.log(`🔄 Revealing secret: ${secret}`);
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    console.log('🔄 Withdrawing from escrows...');
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    const txHash = '0x' + Math.random().toString(16).slice(2).padStart(64, '0');
    return txHash;
  }

  async getSwapMetadata(swapId: string) {
    return {
      swapId,
      direction: Math.random() > 0.5 ? 'eth-to-aptos' : 'aptos-to-eth' as const,
      ethOrderHash: '0x' + Math.random().toString(16).slice(2).padStart(64, '0'),
      ethEscrowAddress: '0x' + Math.random().toString(16).slice(2).padStart(40, '0'),
      aptosEscrowId: Math.floor(Math.random() * 1000).toString(),
      makerEthAddress: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
      takerEthAddress: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
      makerAptosAddress: '0x1',
      takerAptosAddress: '0x2',
      amountEth: '0.1',
      amountAptos: '10',
      secretHash: '0x' + Math.random().toString(16).slice(2).padStart(64, '0'),
      createdAt: Math.floor(Date.now() / 1000) - 300, // 5 minutes ago
      status: 'active' as const
    };
  }
}

/**
 * Demo: Complete Cross-chain Swap
 * 
 * This demo shows how to:
 * 1. Complete a swap by revealing the secret
 * 2. Withdraw funds from both escrows
 * 3. Verify the swap completion
 */

async function completeSwapDemo() {
  console.log('🎯 Starting Swap Completion Demo\n');

  // Example swap info (in practice this would come from user input or database)
  const swapInfo = {
    swapId: process.argv[2] || '0x' + Math.random().toString(16).slice(2).padStart(64, '0'),
    secret: process.argv[3] || '0x' + Math.random().toString(16).slice(2).padStart(64, '0'),
    secretHash: '0x' + Math.random().toString(16).slice(2).padStart(64, '0'),
    direction: 'eth-to-aptos'
  };

  console.log('📋 Swap Information:');
  console.log(`- Swap ID: ${swapInfo.swapId}`);
  console.log(`- Secret: ${swapInfo.secret}`);
  console.log(`- Direction: ${swapInfo.direction}\n`);

  // Configuration
  const ethConfig = {
    providerUrl: process.env.ETH_RPC_URL || 'https://ethereum-sepolia.blockpi.network/v1/rpc/public',
    resolverAddress: process.env.ETH_RESOLVER_ADDRESS || '0x1234567890123456789012345678901234567890',
    privateKey: process.env.ETH_PRIVATE_KEY,
    chainId: 11155111
  };

  const aptosConfig = {
    nodeUrl: process.env.APTOS_NODE_URL || 'https://fullnode.devnet.aptoslabs.com/v1',
    faucetUrl: process.env.APTOS_FAUCET_URL || 'https://faucet.devnet.aptoslabs.com',
    privateKey: process.env.APTOS_PRIVATE_KEY,
    chainId: 2
  };

  // Initialize SDK
  const sdk = new MockEthereumAptosSwapSDK(ethConfig, aptosConfig);

  try {
    // Get current swap status
    console.log('📊 Checking current swap status...');
    const swapMetadata = await sdk.getSwapMetadata(swapInfo.swapId);
    
    console.log('📋 Current Swap Status:');
    console.log(`- Direction: ${swapMetadata.direction}`);
    console.log(`- Status: ${swapMetadata.status}`);
    console.log(`- Amount ETH: ${swapMetadata.amountEth} ETH`);
    console.log(`- Amount Aptos: ${swapMetadata.amountAptos} APT`);
    console.log(`- Created: ${new Date(swapMetadata.createdAt * 1000).toLocaleString()}\n`);

    if (swapMetadata.status !== 'active') {
      console.log('⚠️  Swap is not active. Cannot complete.');
      return;
    }

    // Check if we're in the withdrawal period
    const now = Math.floor(Date.now() / 1000);
    const withdrawalStart = swapMetadata.createdAt + 300; // 5 minutes after creation
    const withdrawalEnd = swapMetadata.createdAt + 3600;  // 1 hour after creation
    
    console.log('⏰ Timelock Status:');
    console.log(`- Current time: ${new Date(now * 1000).toLocaleString()}`);
    console.log(`- Withdrawal start: ${new Date(withdrawalStart * 1000).toLocaleString()}`);
    console.log(`- Withdrawal end: ${new Date(withdrawalEnd * 1000).toLocaleString()}\n`);

    if (now < withdrawalStart) {
      console.log('⏳ Withdrawal period has not started yet. Please wait...');
      return;
    }

    if (now >= withdrawalEnd) {
      console.log('⏰ Withdrawal period has ended. Swap can only be cancelled now.');
      return;
    }

    console.log('✅ Withdrawal period is active. Proceeding with completion...\n');

    // Complete the swap
    console.log('🎯 Completing swap...');
    console.log('This will:');
    
    if (swapMetadata.direction === 'eth-to-aptos') {
      console.log(`1. Reveal secret on Aptos to withdraw ${swapMetadata.amountAptos} APT`);
      console.log(`2. Use revealed secret on Ethereum to withdraw ${swapMetadata.amountEth} ETH`);
    } else {
      console.log(`1. Reveal secret on Ethereum to withdraw ${swapMetadata.amountEth} ETH`);
      console.log(`2. Use revealed secret on Aptos to withdraw ${swapMetadata.amountAptos} APT`);
    }
    
    console.log('\n🔄 Starting completion process...');
    
    const completionTxHash = await sdk.completeSwap(swapInfo.swapId, swapInfo.secret);
    
    console.log('✅ Swap completed successfully!');
    console.log(`Transaction Hash: ${completionTxHash}\n`);

    // Show completion summary
    console.log('🎉 Completion Summary:');
    console.log(`- Swap ID: ${swapInfo.swapId}`);
    console.log(`- Secret revealed: ${swapInfo.secret}`);
    console.log(`- Direction: ${swapMetadata.direction}`);
    
    if (swapMetadata.direction === 'eth-to-aptos') {
      console.log(`- Taker received: ${swapMetadata.amountAptos} APT on Aptos`);
      console.log(`- Maker can now claim: ${swapMetadata.amountEth} ETH on Ethereum`);
    } else {
      console.log(`- Taker received: ${swapMetadata.amountEth} ETH on Ethereum`);
      console.log(`- Maker can now claim: ${swapMetadata.amountAptos} APT on Aptos`);
    }
    
    console.log('\n🔗 Cross-chain atomic swap completed successfully!');
    console.log('Both parties have received their funds on their respective chains.');

  } catch (error) {
    console.error('❌ Error completing swap:', error);
    
    console.log('\n🔧 Troubleshooting:');
    console.log('1. Check if the secret is correct');
    console.log('2. Verify the swap is still in withdrawal period');
    console.log('3. Ensure you have sufficient gas/fees on both chains');
    console.log('4. Check network connectivity');
  }
}

// Run the demo
if (require.main === module) {
  console.log('Usage: npm run demo:complete-swap [swapId] [secret]');
  console.log('Example: npm run demo:complete-swap 0x123... 0xabc...\n');
  
  completeSwapDemo()
    .then(() => {
      console.log('\n🎉 Completion demo finished!');
      process.exit(0);
    })
    .catch((error) => {
      console.error('\n💥 Completion demo failed:', error);
      process.exit(1);
    });
}

export { completeSwapDemo };
