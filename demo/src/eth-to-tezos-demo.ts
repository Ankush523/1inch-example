import 'dotenv/config'
import {TezosEthereumBridgeSDK} from '../../sdk/dist/tezos-sdk'

/**
 * Demo: ETH to Tezos Cross-Chain Swap
 * This demonstrates initiating a swap from Ethereum to Tezos
 */
async function ethToTezosDemo() {
    console.log('🚀 ETH to Tezos Cross-Chain Swap Demo (Simulation Mode)')
    console.log('====================================================\n')

    // Configuration
    const config = {
        tezosRpc: process.env.TEZOS_RPC_URL || 'https://ghostnet.tezos.marigold.dev',
        tezosPrivateKey: process.env.TEZOS_PRIVATE_KEY!,
        ethRpc: process.env.ETH_TESTNET_RPC!,
        ethPrivateKey: process.env.DEPLOYER_PRIVATE_KEY!,
        resolverAddress: process.env.TEZOS_RESOLVER_ADDRESS || '0x...',
        // Use null for simulation mode to avoid contract validation
        tezosEscrowAddress: undefined,
        tezosResolverAddress: undefined
    }

    console.log('🔧 Configuration:')
    console.log(`Tezos RPC: ${config.tezosRpc}`)
    console.log(`ETH RPC: ${config.ethRpc}`)
    console.log(`Resolver Address: ${config.resolverAddress}`)
    console.log(`Tezos Escrow: ${config.tezosEscrowAddress}`)
    console.log('')

    // Initialize SDK
    const sdk = new TezosEthereumBridgeSDK(
        config.tezosRpc,
        config.tezosPrivateKey,
        config.ethRpc,
        config.ethPrivateKey,
        config.resolverAddress,
        config.tezosEscrowAddress,
        config.tezosResolverAddress
    )

    // Swap parameters
    const swapParams = {
        makerEthAddress: process.env.MAKER_ETH_ADDRESS || '0x74946022285dD6AdC4554aABB13d82da96B8E422',
        takerEthAddress: process.env.TAKER_ETH_ADDRESS || '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
        makerTezosAddress: process.env.MAKER_TEZOS_ADDRESS || 'tz1YourTezosAddress...',
        takerTezosAddress: process.env.TAKER_TEZOS_ADDRESS || 'tz1RecipientTezosAddress...',
        tokenEth: process.env.ETH_TOKEN_ADDRESS || '0x0000000000000000000000000000000000000000', // ETH
        amountEth: '0.001', // 0.001 ETH
        amountTezos: '2' // 2 XTZ
    }

    console.log('📝 Swap Configuration:')
    console.log(`ETH Amount: ${swapParams.amountEth} ETH`)
    console.log(`Tezos Amount: ${swapParams.amountTezos} XTZ`)
    console.log(`Maker ETH: ${swapParams.makerEthAddress}`)
    console.log(`Taker Tezos: ${swapParams.takerTezosAddress}`)
    console.log('')

    try {
        // Step 1: Initiate the swap (simulation mode)
        console.log('Step 1: Initiating ETH to Tezos swap (Simulation)...')
        
        // Generate mock swap data for demonstration
        const mockSecret = sdk.generateSecret()
        const mockSwapId = '0x' + Math.random().toString(16).slice(2).padStart(64, '0')
        
        const result = {
            txHash: '0x' + Math.random().toString(16).slice(2).padStart(64, '0'),
            swapId: mockSwapId,
            secret: mockSecret.secret,
            secretHash: mockSecret.secretHash
        }

        console.log('✅ Swap initiated successfully! (Simulated)')
        console.log(`Transaction Hash: ${result.txHash}`)
        console.log(`Swap ID: ${result.swapId}`)
        console.log(`Secret: ${result.secret} (KEEP THIS SAFE!)`)
        console.log(`Secret Hash: ${result.secretHash}`)
        console.log('')

        // Step 2: Simulate waiting for Tezos escrow setup
        console.log('Step 2: Waiting for Tezos escrow to be set up...')
        console.log('(In a real scenario, the counterparty would set up the Tezos escrow)')
        console.log('')

        // Step 3: Simulate swap details
        console.log('Step 3: Checking swap details (Simulated)...')
        const mockSwapDetails = {
            swapId: result.swapId,
            status: 'active',
            amountEth: '1000000000000000', // 0.001 ETH in wei
            amountTezos: '2000000', // 2 XTZ in mutez
            tezosEscrowAddress: 'KT1MockEscrowForDemo123456789'
        }
        console.log('Swap Details:', mockSwapDetails)
        console.log('')

        // Step 4: Complete the swap (simulate)
        console.log('Step 4: Completing swap by revealing secret (Simulation)...')
        
        console.log('4a. Redeeming Tezos escrow (Simulated)...')
        console.log('✅ Tezos redemption successful (Simulated)')

        console.log('4b. Completing Ethereum side (Simulated)...')
        const mockCompleteTx = '0x' + Math.random().toString(16).slice(2).padStart(64, '0')
        console.log(`✅ Swap completed! Transaction: ${mockCompleteTx}`)

        console.log('\n🎉 ETH to Tezos swap demo completed successfully!')
        console.log('📝 Note: This was a simulation. To run with real contracts:')
        console.log('   1. Deploy Tezos contracts using: npm run deploy:tezos')
        console.log('   2. Update TEZOS_ESCROW_ADDRESS in .env')
        console.log('   3. Ensure sufficient balances on both chains')
    } catch (error) {
        console.error('❌ Error during swap:', error)
    }
}

// Execute the demo
if (require.main === module) {
    ethToTezosDemo()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error('Demo failed:', error)
            process.exit(1)
        })
}

export {ethToTezosDemo}
