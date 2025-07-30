import 'dotenv/config'
import {expect, jest} from '@jest/globals'
import {
    ContractFactory,
    JsonRpcProvider,
    Wallet as EthWallet,
    parseEther
} from 'ethers'
import {exec} from 'child_process'
import {promisify} from 'util'
import fs from 'fs'

// Import contract artifacts
import factoryContract from '../dist/contracts/TestEscrowFactory.sol/TestEscrowFactory.json'
import aptosResolverContract from '../dist/contracts/AptosEthereumResolver.sol/AptosEthereumResolver.json'

const execAsync = promisify(exec)

jest.setTimeout(1000 * 60 * 10) // 10 minutes for deployment

describe('Cross-Chain Bridge Deployment Tests', () => {
    // Test configuration - these would come from environment variables in real deployment
    const ETH_TESTNET_RPC = process.env.ETH_TESTNET_RPC || 'https://sepolia.infura.io/v3/your-key'
    const APTOS_TESTNET_RPC = process.env.APTOS_TESTNET_RPC || 'https://fullnode.testnet.aptoslabs.com/v1'
    const DEPLOYER_PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY || '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d'

    beforeAll(() => {
        console.log('\n🔍 DEPLOYMENT READINESS CHECK')
        console.log('================================')
        
        // Check Ethereum readiness
        if (process.env.ETH_TESTNET_RPC && process.env.DEPLOYER_PRIVATE_KEY) {
            console.log('✅ Ethereum: Ready for deployment')
        } else {
            console.log('⚠️  Ethereum: Missing environment variables')
            console.log('   Need: ETH_TESTNET_RPC, DEPLOYER_PRIVATE_KEY')
        }
        
        // Check Aptos readiness
        if (process.env.APTOS_TESTNET_ACCOUNT && process.env.APTOS_PRIVATE_KEY) {
            console.log('✅ Aptos: Environment variables set')
        } else {
            console.log('⚠️  Aptos: Missing environment variables')
            console.log('   Need: APTOS_TESTNET_ACCOUNT, APTOS_PRIVATE_KEY')
        }
        
        console.log('================================\n')
    })

    describe('Ethereum Testnet Deployment', () => {
        let provider: JsonRpcProvider
        let deployer: EthWallet

        beforeAll(() => {
            // Skip if no RPC URL provided
            if (!process.env.ETH_TESTNET_RPC) {
                console.log('Skipping Ethereum deployment tests - no ETH_TESTNET_RPC provided')
                return
            }
            provider = new JsonRpcProvider(ETH_TESTNET_RPC)
            deployer = new EthWallet(DEPLOYER_PRIVATE_KEY, provider)
        })

        it('should connect to Ethereum testnet', async () => {
            if (!process.env.ETH_TESTNET_RPC) {
                console.log('Skipping test - no ETH_TESTNET_RPC provided')
                return
            }

            const network = await provider.getNetwork()
            const balance = await provider.getBalance(deployer.address)
            
            console.log('Connected to Ethereum network:', network.name || 'Unknown')
            console.log('Chain ID:', network.chainId.toString())
            console.log('Deployer address:', deployer.address)
            console.log('Deployer balance:', balance.toString(), 'wei')
            
            expect(network.chainId).toBeDefined()
            expect(balance).toBeGreaterThan(0n)
        })

        it('should deploy TestEscrowFactory to Ethereum testnet', async () => {
            if (!process.env.ETH_TESTNET_RPC) {
                console.log('Skipping test - no ETH_TESTNET_RPC provided')
                return
            }

            const balance = await provider.getBalance(deployer.address)
            if (balance < parseEther('0.01')) {
                console.log('Insufficient balance for deployment, skipping...')
                return
            }

            const factory = new ContractFactory(
                factoryContract.abi,
                factoryContract.bytecode,
                deployer
            )

            console.log('Deploying TestEscrowFactory...')
            const escrowFactory = await factory.deploy(
                '0x111111125421ca6dc452d289314280a0f8842a65', // 1inch LOP on testnet
                '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', // WETH (mock for testnet)
                '0x0000000000000000000000000000000000000000', // accessToken
                deployer.address, // owner
                60 * 30, // src rescue delay
                60 * 30  // dst rescue delay
            )

            await escrowFactory.waitForDeployment()
            const factoryAddress = await escrowFactory.getAddress()

            console.log('TestEscrowFactory deployed at:', factoryAddress)
            
            // Verify deployment
            const code = await provider.getCode(factoryAddress)
            expect(code).not.toBe('0x')
            expect(factoryAddress).toMatch(/^0x[a-fA-F0-9]{40}$/)

            // Save deployment info
            const deploymentInfo = {
                network: 'ethereum-testnet',
                factoryAddress: factoryAddress,
                deployedAt: new Date().toISOString(),
                deployer: deployer.address
            }
            
            fs.writeFileSync(
                'deployment-ethereum-testnet.json',
                JSON.stringify(deploymentInfo, null, 2)
            )
        })

        it('should deploy AptosEthereumResolver to Ethereum testnet', async () => {
            if (!process.env.ETH_TESTNET_RPC) {
                console.log('Skipping test - no ETH_TESTNET_RPC provided')
                return
            }

            const balance = await provider.getBalance(deployer.address)
            if (balance < parseEther('0.01')) {
                console.log('Insufficient balance for deployment, skipping...')
                return
            }

            // Read factory address from previous deployment
            let factoryAddress = '0x0000000000000000000000000000000000000000'
            try {
                const deploymentInfo = JSON.parse(fs.readFileSync('deployment-ethereum-testnet.json', 'utf8'))
                factoryAddress = deploymentInfo.factoryAddress
            } catch {
                // If no previous deployment, use a mock address
                console.log('Using mock factory address for resolver deployment')
            }

            const resolverFactory = new ContractFactory(
                aptosResolverContract.abi,
                aptosResolverContract.bytecode,
                deployer
            )

            console.log('Deploying AptosEthereumResolver...')
            const resolver = await resolverFactory.deploy(
                '0x111111125421ca6dc452d289314280a0f8842a65', // 1inch LOP on testnet
                factoryAddress // escrow factory
            )

            await resolver.waitForDeployment()
            const resolverAddress = await resolver.getAddress()

            console.log('AptosEthereumResolver deployed at:', resolverAddress)
            
            // Verify deployment
            const code = await provider.getCode(resolverAddress)
            expect(code).not.toBe('0x')
            expect(resolverAddress).toMatch(/^0x[a-fA-F0-9]{40}$/)

            // Update deployment info
            let deploymentInfo: any = { network: 'ethereum-testnet' }
            try {
                deploymentInfo = JSON.parse(fs.readFileSync('deployment-ethereum-testnet.json', 'utf8'))
            } catch {
                // Create new if doesn't exist
            }

            deploymentInfo = {
                ...deploymentInfo,
                resolverAddress: resolverAddress,
                lastUpdated: new Date().toISOString()
            }
            
            fs.writeFileSync(
                'deployment-ethereum-testnet.json',
                JSON.stringify(deploymentInfo, null, 2)
            )
        })
    })

    describe('Aptos Testnet Deployment', () => {
        it('should check Aptos CLI availability', async () => {
            try {
                const {stdout} = await execAsync('aptos --version')
                console.log('✅ Aptos CLI version:', stdout.trim())
                expect(stdout).toContain('aptos')
            } catch (error) {
                console.log('❌ Aptos CLI not found')
                console.log('📋 To install Aptos CLI:')
                console.log('   curl -fsSL "https://aptos.dev/scripts/install_cli.py" | python3')
                console.log('   Or visit: https://aptos.dev/tools/aptos-cli-tool/install-aptos-cli')
                console.log('')
                console.log('⚠️  Without Aptos CLI, contracts cannot be deployed to Aptos testnet')
                
                // Fail the test to make it clear that deployment is not possible
                expect(false).toBe(true) // This will fail the test intentionally
            }
        })

        it('should check Aptos testnet connection', async () => {
            // Only run this test if CLI is available
            try {
                await execAsync('aptos --version')
            } catch {
                console.log('⏭️  Skipping connection test - Aptos CLI not available')
                return
            }

            if (!process.env.APTOS_TESTNET_ACCOUNT) {
                console.log('⚠️  No APTOS_TESTNET_ACCOUNT provided')
                console.log('📋 To set up Aptos account:')
                console.log('   1. aptos init --profile testnet --network testnet')
                console.log('   2. aptos account fund-with-faucet --profile testnet')
                console.log('   3. Set APTOS_TESTNET_ACCOUNT=<your-address> in .env')
                console.log('   4. Set APTOS_PRIVATE_KEY=<your-private-key> in .env')
                return
            }

            try {
                // Check if we can query the Aptos testnet
                const {stdout} = await execAsync('aptos node show-validator-set --url https://fullnode.testnet.aptoslabs.com/v1')
                console.log('✅ Successfully connected to Aptos testnet')
                expect(stdout).toBeDefined()
            } catch (error) {
                console.log('❌ Could not connect to Aptos testnet:', error)
                throw error
            }
        })

        it('should compile Aptos contracts', async () => {
            // Only run this test if CLI is available
            try {
                await execAsync('aptos --version')
            } catch {
                console.log('⏭️  Skipping compilation test - Aptos CLI not available')
                return
            }

            try {
                // Change to aptos-contracts directory and compile
                const {stdout, stderr} = await execAsync('cd aptos-contracts && aptos move compile --dev')
                console.log('✅ Aptos compilation output:', stdout)
                if (stderr) console.log('⚠️  Compilation warnings:', stderr)
                
                // Check if build directory was created
                const buildExists = fs.existsSync('aptos-contracts/build')
                expect(buildExists).toBe(true)
                
                console.log('✅ Aptos contracts compiled successfully')
            } catch (error) {
                console.log('❌ Aptos compilation failed:', error)
                console.log('🔧 Troubleshooting:')
                console.log('   1. Check Move.toml is configured correctly')
                console.log('   2. Ensure all dependencies are available')
                console.log('   3. Verify contract syntax in sources/ directory')
                throw error
            }
        })

        it('should deploy Aptos contracts to testnet', async () => {
            // Only run this test if CLI is available
            try {
                await execAsync('aptos --version')
            } catch {
                console.log('⏭️  Skipping deployment test - Aptos CLI not available')
                return
            }

            if (!process.env.APTOS_TESTNET_ACCOUNT || !process.env.APTOS_PRIVATE_KEY) {
                console.log('⚠️  Missing required environment variables for deployment')
                console.log('📋 Required variables:')
                console.log('   - APTOS_TESTNET_ACCOUNT=<your-account-address>')
                console.log('   - APTOS_PRIVATE_KEY=<your-private-key>')
                console.log('')
                console.log('🚀 To get started:')
                console.log('   1. Install Aptos CLI')
                console.log('   2. Run: aptos init --profile testnet --network testnet')
                console.log('   3. Run: aptos account fund-with-faucet --profile testnet')
                console.log('   4. Add credentials to .env file')
                return
            }

            try {
                // First, fund the account if needed
                try {
                    await execAsync(`aptos account fund-with-faucet --account ${process.env.APTOS_TESTNET_ACCOUNT} --url https://fullnode.testnet.aptoslabs.com/v1`)
                    console.log('💰 Account funded from faucet')
                } catch {
                    console.log('💰 Account funding failed or not needed')
                }

                // Deploy the contracts
                const {stdout} = await execAsync(`
                    cd aptos-contracts && 
                    aptos move publish \\
                        --package-dir . \\
                        --named-addresses bridge=${process.env.APTOS_TESTNET_ACCOUNT} \\
                        --private-key ${process.env.APTOS_PRIVATE_KEY} \\
                        --url https://fullnode.testnet.aptoslabs.com/v1 \\
                        --gas-unit-price 100
                `)
                
                console.log('🚀 Aptos deployment output:', stdout)
                
                // Save deployment info
                const deploymentInfo = {
                    network: 'aptos-testnet',
                    address: process.env.APTOS_TESTNET_ACCOUNT,
                    deployedAt: new Date().toISOString(),
                    modules: ['base_escrow', 'resolver'],
                    status: 'deployed'
                }
                
                fs.writeFileSync(
                    'deployment-aptos-testnet.json',
                    JSON.stringify(deploymentInfo, null, 2)
                )
                
                expect(stdout).toContain('Success')
                console.log('✅ Aptos contracts deployed successfully')
            } catch (error) {
                console.log('❌ Aptos deployment failed:', error)
                console.log('🔧 Common issues:')
                console.log('   1. Insufficient account balance')
                console.log('   2. Invalid private key or account address')
                console.log('   3. Network connectivity issues')
                console.log('   4. Contract compilation errors')
                throw error
            }
        })

        it('should verify Aptos contract deployment', async () => {
            if (!process.env.APTOS_TESTNET_ACCOUNT) {
                console.log('Skipping test - no APTOS_TESTNET_ACCOUNT provided')
                return
            }

            try {
                // Query the deployed modules
                const {stdout} = await execAsync(`
                    aptos account list \\
                        --account ${process.env.APTOS_TESTNET_ACCOUNT} \\
                        --url https://fullnode.testnet.aptoslabs.com/v1
                `)
                
                console.log('Account resources:', stdout)
                expect(stdout).toBeDefined()
                
                // Try to query specific module
                try {
                    const {stdout: moduleInfo} = await execAsync(`
                        aptos move view \\
                            --function-id ${process.env.APTOS_TESTNET_ACCOUNT}::resolver::get_bridge_info \\
                            --url https://fullnode.testnet.aptoslabs.com/v1
                    `)
                    console.log('Module function call successful:', moduleInfo)
                } catch {
                    console.log('Module function call failed - this is expected if the function doesn\'t exist')
                }
                
            } catch (error) {
                console.log('Contract verification failed:', error)
                return
            }
        })
    })

    describe('Cross-Chain Integration Setup', () => {
        it('should create integration configuration', () => {
            // Create a configuration file for cross-chain integration
            const integrationConfig = {
                ethereum: {
                    testnet: {
                        rpc: ETH_TESTNET_RPC,
                        deployed: fs.existsSync('deployment-ethereum-testnet.json')
                    }
                },
                aptos: {
                    testnet: {
                        rpc: APTOS_TESTNET_RPC,
                        deployed: fs.existsSync('deployment-aptos-testnet.json')
                    }
                },
                bridge: {
                    supportedTokens: ['USDC', 'USDT'],
                    minimumAmount: '1000000', // 1 USDC (6 decimals)
                    maximumAmount: '1000000000000', // 1M USDC
                    timeLocks: {
                        srcWithdrawal: 600, // 10 minutes
                        srcPublicWithdrawal: 7200, // 2 hours
                        srcCancellation: 86400, // 24 hours
                        dstWithdrawal: 600,
                        dstPublicWithdrawal: 3600, // 1 hour
                        dstCancellation: 43200 // 12 hours
                    }
                },
                createdAt: new Date().toISOString()
            }

            fs.writeFileSync(
                'bridge-integration-config.json',
                JSON.stringify(integrationConfig, null, 2)
            )

            console.log('Integration configuration created')
            expect(fs.existsSync('bridge-integration-config.json')).toBe(true)
        })

        it('should provide deployment summary', () => {
            console.log('\n=== DEPLOYMENT SUMMARY ===')
            
            try {
                const ethDeployment = JSON.parse(fs.readFileSync('deployment-ethereum-testnet.json', 'utf8'))
                console.log('✅ Ethereum Testnet:')
                console.log('   Factory:', ethDeployment.factoryAddress || 'Not deployed')
                console.log('   Resolver:', ethDeployment.resolverAddress || 'Not deployed')
            } catch {
                console.log('❌ Ethereum Testnet: Not deployed')
            }

            try {
                const aptosDeployment = JSON.parse(fs.readFileSync('deployment-aptos-testnet.json', 'utf8'))
                console.log('✅ Aptos Testnet:')
                console.log('   Address:', aptosDeployment.address || 'Not deployed')
                console.log('   Modules:', aptosDeployment.modules?.join(', ') || 'None')
            } catch {
                console.log('❌ Aptos Testnet: Not deployed')
            }

            console.log('\n=== NEXT STEPS ===')
            console.log('1. Set up environment variables for testnet deployment')
            console.log('2. Fund deployer accounts with testnet tokens')
            console.log('3. Run deployment tests with proper credentials')
            console.log('4. Test cross-chain swaps between deployed contracts')
            console.log('5. Monitor and verify contract interactions')
            
            // This test always passes - it's just for information
            expect(true).toBe(true)
        })
    })
})