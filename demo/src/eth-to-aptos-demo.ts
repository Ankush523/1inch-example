import 'dotenv/config'

// Simplified types for demo
interface EthereumConfig {
    providerUrl: string
    resolverAddress: string
    privateKey?: string
    chainId: number
}

interface AptosConfig {
    nodeUrl: string
    faucetUrl?: string
    privateKey?: string
    chainId: number
}

interface SwapParams {
    direction: 'eth-to-aptos' | 'aptos-to-eth'
    amountEth: string
    amountAptos: string
    makerEthAddress: string
    takerEthAddress: string
    makerAptosAddress: string
    takerAptosAddress: string
    tokenEth: string
    tokenAptos: string
    secretHash?: string
    secret?: string
}

// Mock SDK for demo purposes
class MockEthereumAptosSwapSDK {
    constructor(ethConfig: EthereumConfig, aptosConfig: AptosConfig) {
        console.log('📡 SDK initialized with:')
        console.log(`- Ethereum: ${ethConfig.providerUrl}`)
        console.log(`- Aptos: ${aptosConfig.nodeUrl}`)
    }

    generateSecret() {
        const mockSecret = '0x' + Math.random().toString(16).slice(2).padStart(64, '0')
        const mockSecretHash = '0x' + Math.random().toString(16).slice(2).padStart(64, '0')
        return {secret: mockSecret, secretHash: mockSecretHash}
    }

    async initiateEthToAptosSwap(params: SwapParams) {
        console.log('🔄 Creating Aptos escrow...')
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
            direction: 'eth-to-aptos' as const,
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
            createdAt: Math.floor(Date.now() / 1000),
            status: 'active' as const
        }
    }
}

/**
 * Demo: Ethereum to Aptos Cross-chain Swap
 *
 * This demo shows how to:
 * 1. Initialize the SDK with Ethereum and Aptos configurations
 * 2. Generate a secret for the atomic swap
 * 3. Initiate a swap from Ethereum to Aptos
 * 4. Monitor the swap status
 */

async function ethToAptosDemo() {
    console.log('🌉 Starting Ethereum to Aptos Cross-chain Swap Demo\n')

    // Configuration
    const ethConfig: EthereumConfig = {
        providerUrl: process.env.ETH_RPC_URL || 'https://ethereum-sepolia.blockpi.network/v1/rpc/public',
        resolverAddress: process.env.ETH_RESOLVER_ADDRESS || '0x1234567890123456789012345678901234567890',
        privateKey: process.env.ETH_PRIVATE_KEY,
        chainId: 11155111 // Sepolia
    }

    const aptosConfig: AptosConfig = {
        nodeUrl: process.env.APTOS_NODE_URL || 'https://fullnode.devnet.aptoslabs.com/v1',
        faucetUrl: process.env.APTOS_FAUCET_URL || 'https://faucet.devnet.aptoslabs.com',
        privateKey: process.env.APTOS_PRIVATE_KEY,
        chainId: 2 // Devnet
    }

    // Initialize SDK
    console.log('📡 Initializing SDK...')
    const sdk = new MockEthereumAptosSwapSDK(ethConfig, aptosConfig)

    // Generate secret for atomic swap
    console.log('🔐 Generating secret...')
    const {secret, secretHash} = sdk.generateSecret()
    console.log(`Secret: ${secret}`)
    console.log(`Secret Hash: ${secretHash}\n`)

    // Swap parameters
    const swapParams: SwapParams = {
        direction: 'eth-to-aptos',
        amountEth: '0.1', // 0.1 ETH
        amountAptos: '10', // 10 APT
        makerEthAddress: process.env.MAKER_ETH_ADDRESS || '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266',
        takerEthAddress: process.env.TAKER_ETH_ADDRESS || '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
        makerAptosAddress: process.env.MAKER_APTOS_ADDRESS || '0x1',
        takerAptosAddress: process.env.TAKER_APTOS_ADDRESS || '0x2',
        tokenEth: process.env.ETH_TOKEN_ADDRESS || '0x0000000000000000000000000000000000000000', // ETH
        tokenAptos: process.env.APTOS_TOKEN_ADDRESS || '0x1::aptos_coin::AptosCoin',
        secret,
        secretHash
    }

    try {
        // Initiate the swap
        console.log('🚀 Initiating ETH to Aptos swap...')
        console.log(`Amount ETH: ${swapParams.amountEth} ETH`)
        console.log(`Amount Aptos: ${swapParams.amountAptos} APT`)
        console.log(`Maker (ETH): ${swapParams.makerEthAddress}`)
        console.log(`Taker (ETH): ${swapParams.takerEthAddress}`)
        console.log(`Maker (Aptos): ${swapParams.makerAptosAddress}`)
        console.log(`Taker (Aptos): ${swapParams.takerAptosAddress}\n`)

        const result = await sdk.initiateEthToAptosSwap(swapParams)

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
            console.log(`- Aptos Escrow ID: ${swapMetadata.aptosEscrowId}`)
            console.log(`- Created At: ${new Date(swapMetadata.createdAt * 1000).toISOString()}\n`)
        } catch (error) {
            console.log('⚠️  Could not fetch swap metadata (contract may not be deployed yet)\n')
        }

        // Instructions for next steps
        console.log('📝 Next Steps:')
        console.log('1. Wait for the withdrawal period to start')
        console.log('2. The taker can complete the swap by revealing the secret:')
        console.log(`   - Secret: ${secret}`)
        console.log(`   - Use: npm run demo:complete-swap`)
        console.log('3. Or the maker can cancel after the cancellation period\n')

        // Save swap info for completion demo
        const swapInfo = {
            swapId: result.swapId,
            secret,
            secretHash,
            direction: 'eth-to-aptos'
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
    ethToAptosDemo()
        .then(() => {
            console.log('\n🎉 Demo completed!')
            process.exit(0)
        })
        .catch((error) => {
            console.error('\n💥 Demo failed:', error)
            process.exit(1)
        })
}

export {ethToAptosDemo}
