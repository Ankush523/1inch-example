import 'dotenv/config'

// Simplified types for demo
interface EthereumConfig {
    providerUrl: string
    resolverAddress: string
    privateKey?: string
    chainId: number
}

interface CardanoConfig {
    nodeUrl: string
    networkId: number // 0 = testnet, 1 = mainnet
    privateKey?: string
    chainId: number
}

interface CardanoSwapParams {
    direction: 'eth-to-cardano' | 'cardano-to-eth'
    amountEth: string
    amountCardano: string // in Lovelace (1 ADA = 1,000,000 Lovelace)
    makerEthAddress: string
    takerEthAddress: string
    makerCardanoAddress: string
    takerCardanoAddress: string
    tokenEth: string
    secretHash?: string
    secret?: string
}

// Mock SDK for demo purposes
class MockCardanoEthereumSwapSDK {
    constructor(ethConfig: EthereumConfig, cardanoConfig: CardanoConfig) {
        console.log('📡 SDK initialized with:')
        console.log(`- Ethereum: ${ethConfig.providerUrl}`)
        console.log(
            `- Cardano: ${cardanoConfig.nodeUrl} (Network: ${cardanoConfig.networkId === 0 ? 'Testnet' : 'Mainnet'})`
        )
    }

    generateSecret() {
        const mockSecret = '0x' + Math.random().toString(16).slice(2).padStart(64, '0')
        const mockSecretHash = '0x' + Math.random().toString(16).slice(2).padStart(64, '0')
        return {secret: mockSecret, secretHash: mockSecretHash}
    }

    async initiateEthToCardanoSwap(params: CardanoSwapParams) {
        console.log('🔄 Creating Cardano escrow...')
        await new Promise((resolve) => setTimeout(resolve, 1000))

        console.log('🔄 Creating Ethereum escrow...')
        await new Promise((resolve) => setTimeout(resolve, 1500))

        const swapId = '0x' + Math.random().toString(16).slice(2).padStart(64, '0')
        const txHash = '0x' + Math.random().toString(16).slice(2).padStart(64, '0')

        return {swapId, txHash}
    }

    async getSwapMetadata(swapId: string) {
        return {
            swapId,
            direction: 'eth-to-cardano' as const,
            ethOrderHash: '0x' + Math.random().toString(16).slice(2).padStart(64, '0'),
            ethEscrowAddress: '0x' + Math.random().toString(16).slice(2).padStart(40, '0'),
            cardanoEscrowId: Math.floor(Math.random() * 1000).toString(),
            makerEthAddress: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
            takerEthAddress: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
            makerCardanoAddress: 'addr_test1qpk...',
            takerCardanoAddress: 'addr_test1qpk...',
            amountEth: '0.1',
            amountCardano: '1000000', // 1 ADA in Lovelace
            secretHash: '0x' + Math.random().toString(16).slice(2).padStart(64, '0'),
            createdAt: Math.floor(Date.now() / 1000),
            status: 'active' as const
        }
    }
}

/**
 * Demo: Ethereum to Cardano Cross-chain Swap
 *
 * This demo shows how to:
 * 1. Initialize the SDK with Ethereum and Cardano configurations
 * 2. Generate a secret for the atomic swap
 * 3. Initiate a swap from Ethereum to Cardano
 * 4. Monitor the swap status
 */

async function ethToCardanoDemo() {
    console.log('🌉 Starting Ethereum to Cardano Cross-chain Swap Demo\n')

    // Configuration
    const ethConfig: EthereumConfig = {
        providerUrl: process.env.ETH_RPC_URL || 'https://ethereum-sepolia.blockpi.network/v1/rpc/public',
        resolverAddress: process.env.ETH_RESOLVER_ADDRESS || '0x1234567890123456789012345678901234567890',
        privateKey: process.env.ETH_PRIVATE_KEY,
        chainId: 11155111 // Sepolia
    }

    const cardanoConfig: CardanoConfig = {
        nodeUrl: process.env.CARDANO_NODE_URL || 'https://preprod.cardano-testnet.iohk.io',
        networkId: 0, // Testnet
        privateKey: process.env.CARDANO_PRIVATE_KEY,
        chainId: 3 // Cardano testnet
    }

    // Initialize SDK
    console.log('📡 Initializing SDK...')
    const sdk = new MockCardanoEthereumSwapSDK(ethConfig, cardanoConfig)

    // Generate secret for atomic swap
    console.log('🔐 Generating secret...')
    const {secret, secretHash} = sdk.generateSecret()
    console.log(`Secret: ${secret}`)
    console.log(`Secret Hash: ${secretHash}\n`)

    // Swap parameters
    const swapParams: CardanoSwapParams = {
        direction: 'eth-to-cardano',
        amountEth: '0.1', // 0.1 ETH
        amountCardano: '1000000', // 1 ADA (1,000,000 Lovelace)
        makerEthAddress: process.env.MAKER_ETH_ADDRESS || '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
        takerEthAddress: process.env.TAKER_ETH_ADDRESS || '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
        makerCardanoAddress: process.env.MAKER_CARDANO_ADDRESS || 'addr_test1qpk...',
        takerCardanoAddress: process.env.TAKER_CARDANO_ADDRESS || 'addr_test1qpk...',
        tokenEth: process.env.ETH_TOKEN_ADDRESS || '0x0000000000000000000000000000000000000000', // ETH
        secret,
        secretHash
    }

    try {
        // Initiate the swap
        console.log('🚀 Initiating ETH to Cardano swap...')
        console.log(`Amount ETH: ${swapParams.amountEth} ETH`)
        console.log(
            `Amount Cardano: ${swapParams.amountCardano} Lovelace (${Number(swapParams.amountCardano) / 1000000} ADA)`
        )
        console.log(`Maker (ETH): ${swapParams.makerEthAddress}`)
        console.log(`Taker (ETH): ${swapParams.takerEthAddress}`)
        console.log(`Maker (Cardano): ${swapParams.makerCardanoAddress}`)
        console.log(`Taker (Cardano): ${swapParams.takerCardanoAddress}\n`)

        const result = await sdk.initiateEthToCardanoSwap(swapParams)

        console.log('✅ Swap initiated successfully!')
        console.log(`Swap ID: ${result.swapId}`)
        console.log(`Transaction Hash: ${result.txHash}\n`)

        // Wait a moment and check swap status
        console.log('⏳ Checking swap status...')
        await new Promise((resolve) => setTimeout(resolve, 2000))

        try {
            const swapMetadata = await sdk.getSwapMetadata(result.swapId)
            console.log('📊 Swap Metadata:')
            console.log(`- Direction: ${swapMetadata.direction}`)
            console.log(`- Status: ${swapMetadata.status}`)
            console.log(`- ETH Escrow: ${swapMetadata.ethEscrowAddress}`)
            console.log(`- Cardano Escrow ID: ${swapMetadata.cardanoEscrowId}`)
            console.log(`- Created At: ${new Date(swapMetadata.createdAt * 1000).toISOString()}\n`)
        } catch (error) {
            console.log('⚠️  Could not fetch swap metadata (contract may not be deployed yet)\n')
        }

        // Instructions for next steps
        console.log('📝 Next Steps:')
        console.log('1. Wait for the withdrawal period to start')
        console.log('2. The taker can complete the swap by revealing the secret:')
        console.log(`   - Secret: ${secret}`)
        console.log(`   - Use: npm run demo:complete-cardano-swap`)
        console.log('3. Or the maker can cancel after the cancellation period\n')

        // Save swap info for completion demo
        const swapInfo = {
            swapId: result.swapId,
            secret,
            secretHash,
            direction: 'eth-to-cardano'
        }

        // In a real application, this would be stored in a database
        console.log('💾 Swap info (save this for completion):')
        console.log(JSON.stringify(swapInfo, null, 2))
    } catch (error) {
        console.error('❌ Error initiating swap:', error)
    }
}

// Run the demo
if (require.main === module) {
    ethToCardanoDemo()
        .then(() => {
            console.log('\n🎉 Demo completed!')
            process.exit(0)
        })
        .catch((error) => {
            console.error('\n💥 Demo failed:', error)
            process.exit(1)
        })
}

export {ethToCardanoDemo}
