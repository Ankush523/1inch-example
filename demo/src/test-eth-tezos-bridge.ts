import 'dotenv/config'
import { JsonRpcProvider, Contract, formatEther } from 'ethers'

/**
 * Test ETH<>Tezos Bridge Integration
 * This script tests if the bridge is properly configured and deployed
 */
async function testEthTezosBridge() {
    console.log('🧪 Testing ETH<>Tezos Bridge Integration')
    console.log('========================================\n')

    // Configuration
    const ETH_RPC = process.env.ETH_TESTNET_RPC!
    const TEZOS_RESOLVER_ADDRESS = process.env.TEZOS_RESOLVER_ADDRESS!
    
    if (!TEZOS_RESOLVER_ADDRESS || TEZOS_RESOLVER_ADDRESS === '0x...') {
        console.log('❌ TEZOS_RESOLVER_ADDRESS not configured')
        console.log('Please deploy the TezosResolver contract first')
        return
    }

    console.log('📋 Configuration:')
    console.log(`ETH RPC: ${ETH_RPC}`)
    console.log(`Tezos Resolver: ${TEZOS_RESOLVER_ADDRESS}`)
    console.log('')

    try {
        // Test 1: Connect to Ethereum
        console.log('Test 1: Connecting to Ethereum...')
        const provider = new JsonRpcProvider(ETH_RPC)
        const network = await provider.getNetwork()
        console.log(`✅ Connected to ${network.name} (Chain ID: ${network.chainId})`)
        console.log('')

        // Test 2: Check TezosResolver deployment
        console.log('Test 2: Checking TezosResolver deployment...')
        const resolverCode = await provider.getCode(TEZOS_RESOLVER_ADDRESS)
        
        if (resolverCode === '0x') {
            console.log('❌ TezosResolver not deployed at specified address')
            return
        }
        
        console.log('✅ TezosResolver contract found')
        console.log('')

        // Test 3: Test contract interface
        console.log('Test 3: Testing contract interface...')
        const resolverAbi = [
            'function getAllTezosSwaps() view returns (bytes32[])',
            'function swapExists(bytes32) view returns (bool)',
            'function owner() view returns (address)'
        ]
        
        const resolver = new Contract(TEZOS_RESOLVER_ADDRESS, resolverAbi, provider)
        
        try {
            const owner = await resolver.owner()
            console.log(`✅ Contract owner: ${owner}`)
            
            const tezosSwaps = await resolver.getAllTezosSwaps()
            console.log(`✅ Current Tezos swaps: ${tezosSwaps.length}`)
        } catch (error) {
            console.log('⚠️ Contract interface test failed:', (error as Error).message)
        }
        console.log('')

        // Test 4: Check Tezos configuration
        console.log('Test 4: Checking Tezos configuration...')
        const tezosRpc = process.env.TEZOS_RPC_URL
        const tezosEscrow = process.env.TEZOS_ESCROW_ADDRESS
        const tezosResolver = process.env.TEZOS_RESOLVER_ADDRESS_TZ
        
        console.log(`Tezos RPC: ${tezosRpc || 'Not configured'}`)
        console.log(`Tezos Escrow: ${tezosEscrow || 'Not configured'}`)
        console.log(`Tezos Resolver: ${tezosResolver || 'Not configured'}`)
        
        if (tezosRpc && tezosEscrow && tezosResolver) {
            console.log('✅ Tezos configuration complete')
        } else {
            console.log('⚠️ Tezos configuration incomplete')
            console.log('Please run: ./scripts/deploy-tezos.sh')
        }
        console.log('')

        // Test 5: Validate addresses
        console.log('Test 5: Validating address formats...')
        
        // Ethereum address validation
        if (TEZOS_RESOLVER_ADDRESS.length === 42 && TEZOS_RESOLVER_ADDRESS.startsWith('0x')) {
            console.log('✅ Ethereum address format valid')
        } else {
            console.log('❌ Invalid Ethereum address format')
        }
        
        // Tezos address validation
        if (tezosEscrow && tezosResolver) {
            const validTezosEscrow = tezosEscrow.startsWith('KT1') && tezosEscrow.length === 36
            const validTezosResolver = tezosResolver.startsWith('KT1') && tezosResolver.length === 36
            
            if (validTezosEscrow && validTezosResolver) {
                console.log('✅ Tezos address formats valid')
            } else {
                console.log('⚠️ Invalid Tezos address formats')
            }
        }
        console.log('')

        // Test 6: Check balance requirements
        console.log('Test 6: Checking balance requirements...')
        const deployerAddress = process.env.DEPLOYER_ADDRESS || '0x74946022285dD6AdC4554aABB13d82da96B8E422'
        
        try {
            const balance = await provider.getBalance(deployerAddress)
            const ethBalance = parseFloat(formatEther(balance))
            
            console.log(`ETH Balance: ${ethBalance} ETH`)
            
            if (ethBalance >= 0.02) {
                console.log('✅ Sufficient ETH for testing')
            } else {
                console.log('⚠️ Low ETH balance. Consider adding more for testing.')
            }
        } catch (error) {
            console.log('⚠️ Could not check ETH balance')
        }
        console.log('')

        // Final summary
        console.log('🎯 Test Summary:')
        console.log('================')
        console.log('✅ Ethereum connection: Working')
        console.log('✅ TezosResolver deployment: Verified')
        console.log(`${tezosRpc && tezosEscrow && tezosResolver ? '✅' : '⚠️'} Tezos configuration: ${tezosRpc && tezosEscrow && tezosResolver ? 'Complete' : 'Incomplete'}`)
        console.log('')

        if (tezosRpc && tezosEscrow && tezosResolver) {
            console.log('🎉 ETH<>Tezos bridge is ready for testing!')
            console.log('')
            console.log('📝 Next steps:')
            console.log('1. Run ETH to Tezos demo: npx ts-node src/eth-to-tezos-demo.ts')
            console.log('2. Run Tezos to ETH demo: npx ts-node src/tezos-to-eth-demo.ts')
            console.log('3. Test complete swap: npx ts-node src/complete-tezos-swap-demo.ts')
        } else {
            console.log('⚠️ Please complete Tezos deployment first:')
            console.log('   ./scripts/deploy-tezos.sh')
        }

    } catch (error) {
        console.error('❌ Test failed:', (error as Error).message)
    }
}

// Execute the test
if (require.main === module) {
    testEthTezosBridge()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error('Test failed:', error)
            process.exit(1)
        })
}

export { testEthTezosBridge }
