import {TezosToolkit} from '@taquito/taquito'
import {InMemorySigner} from '@taquito/signer'
import {Contract as EthContract, JsonRpcProvider, Wallet} from 'ethers'
import * as crypto from 'crypto'

export interface TezosSwapParams {
    makerEthAddress: string
    takerEthAddress: string
    makerTezosAddress: string
    takerTezosAddress: string
    tokenEth: string
    amountEth: string
    amountTezos: string
    secretHash?: string
}

export interface TezosSwapResult {
    txHash: string
    swapId: string
    secret?: string
    secretHash: string
}

/**
 * Tezos SDK for cross-chain atomic swaps with Ethereum
 */
export class TezosEthereumBridgeSDK {
    private tezos: TezosToolkit
    private ethProvider: JsonRpcProvider
    private ethSigner: Wallet
    private resolverAddress: string
    private tezosEscrowAddress?: string
    private tezosResolverAddress?: string

    constructor(
        tezosRpcUrl: string,
        tezosPrivateKey: string,
        ethRpcUrl: string,
        ethPrivateKey: string,
        resolverAddress: string,
        tezosEscrowAddress?: string,
        tezosResolverAddress?: string
    ) {
        // Initialize Tezos
        this.tezos = new TezosToolkit(tezosRpcUrl)
        this.tezos.setProvider({
            signer: new InMemorySigner(tezosPrivateKey)
        })

        // Initialize Ethereum
        this.ethProvider = new JsonRpcProvider(ethRpcUrl)
        this.ethSigner = new Wallet(ethPrivateKey, this.ethProvider)
        this.resolverAddress = resolverAddress
        this.tezosEscrowAddress = tezosEscrowAddress
        this.tezosResolverAddress = tezosResolverAddress
    }

    /**
     * Generate a random secret and its hash for atomic swaps
     */
    generateSecret(): {secret: string; secretHash: string} {
        const secret = '0x' + crypto.randomBytes(32).toString('hex')
        const secretHash = crypto.createHash('sha256').update(secret).digest('hex')
        return {secret, secretHash: '0x' + secretHash}
    }

    /**
     * Create a secret hash from a given secret
     */
    createSecretHash(secret: string): string {
        const secretHash = crypto.createHash('sha256').update(secret).digest('hex')
        return '0x' + secretHash
    }

    /**
     * Parse UTxO data for Tezos transactions
     */
    parseUTxO(utxoData: any): any {
        // Parse Tezos UTxO format
        return {
            hash: utxoData.hash,
            amount: utxoData.amount,
            address: utxoData.address,
            timestamp: utxoData.timestamp
        }
    }

    /**
     * Validate Tezos address format
     */
    validateTezosAddress(address: string): boolean {
        // Tezos addresses start with tz1, tz2, tz3, or KT1
        const tezosAddressRegex = /^(tz1|tz2|tz3|KT1)[1-9A-HJ-NP-Za-km-z]{33}$/
        return tezosAddressRegex.test(address)
    }

    /**
     * Initiate ETH to Tezos swap
     */
    async initiateEthToTezosSwap(params: TezosSwapParams): Promise<TezosSwapResult> {
        // Generate swap ID and secret if not provided
        const swapId = '0x' + crypto.randomBytes(32).toString('hex')
        let secret = ''
        let secretHash = params.secretHash
        if (!secret || !secretHash) {
            const generated = this.generateSecret()
            secret = generated.secret
            secretHash = generated.secretHash
        }

        // 1. Create Tezos escrow first
        const tezosEscrowAddress = await this.createTezosEscrow({
            ...params,
            swapId,
            secretHash: secretHash!,
            direction: 'eth-to-tezos'
        })

        // 2. Create Ethereum escrow
        const resolverContract = new EthContract(this.resolverAddress, this.getResolverABI(), this.ethSigner)

        // Prepare immutables for Ethereum escrow
        const now = Math.floor(Date.now() / 1000)
        const immutables = {
            orderHash: crypto.createHash('sha256').update(swapId).digest('hex'),
            hashlock: secretHash,
            maker: params.makerEthAddress,
            taker: params.takerEthAddress,
            token: params.tokenEth,
            amount: BigInt(params.amountEth) * BigInt(10 ** 18), // Convert to wei
            safetyDeposit: BigInt(10 ** 16), // 0.01 ETH safety deposit
            timelocks: this.createTimelocks(now)
        }

        // Prepare order (simplified for example)
        const order = {
            salt: crypto.randomBytes(32),
            maker: params.makerEthAddress,
            receiver: params.takerEthAddress,
            makerAsset: params.tokenEth,
            takerAsset: params.tokenEth,
            makingAmount: BigInt(params.amountEth) * BigInt(10 ** 18),
            takingAmount: BigInt(params.amountEth) * BigInt(10 ** 18),
            makerTraits: '0x0000000000000000000000000000000000000000000000000000000000000000'
        }

        const tx = await resolverContract.initiateEthToTezosSwap(
            swapId,
            immutables,
            order,
            crypto.randomBytes(32), // r
            crypto.randomBytes(32), // vs
            BigInt(params.amountEth) * BigInt(10 ** 18), // amount
            '0x0000000000000000000000000000000000000000000000000000000000000000', // takerTraits
            '0x', // args
            params.makerTezosAddress,
            params.takerTezosAddress,
            BigInt(params.amountTezos) * BigInt(10 ** 6), // Convert to mutez
            {value: immutables.safetyDeposit}
        )

        const receipt = await tx.wait()

        return {
            txHash: receipt.transactionHash,
            swapId,
            secret,
            secretHash: secretHash!
        }
    }

    /**
     * Initiate Tezos to ETH swap
     */
    async initiateTezosToEthSwap(params: TezosSwapParams): Promise<TezosSwapResult> {
        // Generate swap ID and secret if not provided
        const swapId = '0x' + crypto.randomBytes(32).toString('hex')
        let secret = ''
        let secretHash = params.secretHash
        if (!secret || !secretHash) {
            const generated = this.generateSecret()
            secret = generated.secret
            secretHash = generated.secretHash
        }

        // 1. Create Tezos escrow first with funds
        const tezosEscrowAddress = await this.createTezosEscrow({
            ...params,
            swapId,
            secretHash: secretHash!,
            direction: 'tezos-to-eth'
        })

        // 2. Create Ethereum destination escrow
        const resolverContract = new EthContract(this.resolverAddress, this.getResolverABI(), this.ethSigner)

        const now = Math.floor(Date.now() / 1000)
        const dstImmutables = {
            orderHash: crypto.createHash('sha256').update(swapId).digest('hex'),
            hashlock: secretHash,
            maker: params.makerEthAddress,
            taker: params.takerEthAddress,
            token: params.tokenEth,
            amount: BigInt(params.amountEth) * BigInt(10 ** 18),
            safetyDeposit: BigInt(10 ** 16), // 0.01 ETH safety deposit
            timelocks: this.createTimelocks(0)
        }

        const tx = await resolverContract.initiateTezosToEthSwap(
            swapId,
            dstImmutables,
            now + 3600, // srcCancellationTimestamp
            params.makerTezosAddress,
            params.takerTezosAddress,
            BigInt(params.amountTezos) * BigInt(10 ** 6), // Convert to mutez
            tezosEscrowAddress,
            {value: dstImmutables.safetyDeposit}
        )

        const receipt = await tx.wait()

        return {
            txHash: receipt.transactionHash,
            swapId,
            secret,
            secretHash: secretHash!
        }
    }

    /**
     * Create Tezos escrow contract
     */
    private async createTezosEscrow(
        params: TezosSwapParams & {
            swapId: string
            secretHash: string
            direction: 'eth-to-tezos' | 'tezos-to-eth'
        }
    ): Promise<string> {
        if (!this.tezosEscrowAddress) {
            throw new Error('Tezos escrow contract address not provided')
        }

        const contract = await this.tezos.contract.at(this.tezosEscrowAddress)

        // Calculate timelock (24 hours from now)
        const timelock = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()

        const secretHashBytes = Buffer.from(params.secretHash.replace('0x', ''), 'hex')

        const operation = await contract.methods
            .initiate(
                secretHashBytes,
                params.direction === 'eth-to-tezos' ? params.takerTezosAddress : params.makerTezosAddress,
                parseInt(params.amountTezos) * 1000000, // Convert to mutez
                timelock
            )
            .send({
                amount: parseInt(params.amountTezos),
                mutez: false
            })

        await operation.confirmation()

        return this.tezosEscrowAddress
    }

    /**
     * Redeem Tezos escrow with secret
     */
    async redeemTezosEscrow(secret: string): Promise<string> {
        if (!this.tezosEscrowAddress) {
            throw new Error('Tezos escrow contract address not provided')
        }

        const contract = await this.tezos.contract.at(this.tezosEscrowAddress)
        const secretBytes = Buffer.from(secret.replace('0x', ''), 'hex')

        const operation = await contract.methods.redeem(secretBytes).send()
        await operation.confirmation()

        return operation.hash
    }

    /**
     * Refund Tezos escrow after timelock
     */
    async refundTezosEscrow(): Promise<string> {
        if (!this.tezosEscrowAddress) {
            throw new Error('Tezos escrow contract address not provided')
        }

        const contract = await this.tezos.contract.at(this.tezosEscrowAddress)

        const operation = await contract.methods.refund(null).send()
        await operation.confirmation()

        return operation.hash
    }

    /**
     * Complete ETH to Tezos swap
     */
    async completeEthToTezosSwap(swapId: string, secret: string): Promise<string> {
        const resolverContract = new EthContract(this.resolverAddress, this.getResolverABI(), this.ethSigner)

        const tx = await resolverContract.completeEthToTezosSwap(swapId, secret)
        const receipt = await tx.wait()

        return receipt.transactionHash
    }

    /**
     * Complete Tezos to ETH swap
     */
    async completeTezosToEthSwap(swapId: string, secret: string): Promise<string> {
        const resolverContract = new EthContract(this.resolverAddress, this.getResolverABI(), this.ethSigner)

        const tx = await resolverContract.completeTezosToEthSwap(swapId, secret)
        const receipt = await tx.wait()

        return receipt.transactionHash
    }

    /**
     * Get swap details
     */
    async getSwapDetails(swapId: string) {
        const resolverContract = new EthContract(this.resolverAddress, this.getResolverABI(), this.ethSigner)

        const swap = await resolverContract.swaps(swapId)
        const tezosData = await resolverContract.getTezosSwapData(swapId)

        return {
            ...swap,
            tezosEscrowAddress: tezosData.tezosEscrowAddress,
            amountTezos: tezosData.amountTezos
        }
    }

    /**
     * Create timelocks for escrow
     */
    private createTimelocks(deployedAt: number) {
        const base = deployedAt || Math.floor(Date.now() / 1000)
        return {
            srcWithdrawal: base + 3600, // 1 hour
            srcPublicWithdrawal: base + 7200, // 2 hours
            srcCancellation: base + 14400, // 4 hours
            srcPublicCancellation: base + 21600 // 6 hours
        }
    }

    /**
     * Get resolver contract ABI
     */
    private getResolverABI(): string[] {
        return [
            'function initiateEthToTezosSwap(bytes32,tuple,tuple,bytes32,bytes32,uint256,uint256,bytes,string,string,uint256) payable',
            'function initiateTezosToEthSwap(bytes32,tuple,uint256,string,string,uint256,string) payable',
            'function completeEthToTezosSwap(bytes32,bytes32)',
            'function completeTezosToEthSwap(bytes32,bytes32)',
            'function swaps(bytes32) view returns (tuple)',
            'function getTezosSwapData(bytes32) view returns (string,uint256)',
            'function swapExists(bytes32) view returns (bool)'
        ]
    }
}
