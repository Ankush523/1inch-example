"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.TezosEthereumBridgeSDK = void 0;
const taquito_1 = require("@taquito/taquito");
const signer_1 = require("@taquito/signer");
const ethers_1 = require("ethers");
const crypto = __importStar(require("crypto"));
class TezosEthereumBridgeSDK {
    constructor(tezosRpcUrl, tezosPrivateKey, ethRpcUrl, ethPrivateKey, resolverAddress, tezosEscrowAddress, tezosResolverAddress) {
        this.tezos = new taquito_1.TezosToolkit(tezosRpcUrl);
        this.tezos.setProvider({
            signer: new signer_1.InMemorySigner(tezosPrivateKey),
        });
        this.ethProvider = new ethers_1.JsonRpcProvider(ethRpcUrl);
        this.ethSigner = new ethers_1.Wallet(ethPrivateKey, this.ethProvider);
        this.resolverAddress = resolverAddress;
        this.tezosEscrowAddress = tezosEscrowAddress;
        this.tezosResolverAddress = tezosResolverAddress;
    }
    generateSecret() {
        const secret = '0x' + crypto.randomBytes(32).toString('hex');
        const secretHash = crypto.createHash('sha256').update(secret).digest('hex');
        return { secret, secretHash: '0x' + secretHash };
    }
    async initiateEthToTezosSwap(params) {
        const swapId = '0x' + crypto.randomBytes(32).toString('hex');
        let secret = '';
        let secretHash = params.secretHash;
        if (!secret || !secretHash) {
            const generated = this.generateSecret();
            secret = generated.secret;
            secretHash = generated.secretHash;
        }
        const tezosEscrowAddress = await this.createTezosEscrow({
            ...params,
            swapId,
            secretHash: secretHash,
            direction: 'eth-to-tezos'
        });
        const resolverContract = new ethers_1.Contract(this.resolverAddress, this.getResolverABI(), this.ethSigner);
        const now = Math.floor(Date.now() / 1000);
        const immutables = {
            orderHash: crypto.createHash('sha256').update(swapId).digest('hex'),
            hashlock: secretHash,
            maker: params.makerEthAddress,
            taker: params.takerEthAddress,
            token: params.tokenEth,
            amount: BigInt(params.amountEth) * BigInt(10 ** 18),
            safetyDeposit: BigInt(10 ** 16),
            timelocks: this.createTimelocks(now)
        };
        const order = {
            salt: crypto.randomBytes(32),
            maker: params.makerEthAddress,
            receiver: params.takerEthAddress,
            makerAsset: params.tokenEth,
            takerAsset: params.tokenEth,
            makingAmount: BigInt(params.amountEth) * BigInt(10 ** 18),
            takingAmount: BigInt(params.amountEth) * BigInt(10 ** 18),
            makerTraits: '0x0000000000000000000000000000000000000000000000000000000000000000'
        };
        const tx = await resolverContract.initiateEthToTezosSwap(swapId, immutables, order, crypto.randomBytes(32), crypto.randomBytes(32), BigInt(params.amountEth) * BigInt(10 ** 18), '0x0000000000000000000000000000000000000000000000000000000000000000', '0x', params.makerTezosAddress, params.takerTezosAddress, BigInt(params.amountTezos) * BigInt(10 ** 6), { value: immutables.safetyDeposit });
        const receipt = await tx.wait();
        return {
            txHash: receipt.transactionHash,
            swapId,
            secret,
            secretHash: secretHash
        };
    }
    async initiateTezosToEthSwap(params) {
        const swapId = '0x' + crypto.randomBytes(32).toString('hex');
        let secret = '';
        let secretHash = params.secretHash;
        if (!secret || !secretHash) {
            const generated = this.generateSecret();
            secret = generated.secret;
            secretHash = generated.secretHash;
        }
        const tezosEscrowAddress = await this.createTezosEscrow({
            ...params,
            swapId,
            secretHash: secretHash,
            direction: 'tezos-to-eth'
        });
        const resolverContract = new ethers_1.Contract(this.resolverAddress, this.getResolverABI(), this.ethSigner);
        const now = Math.floor(Date.now() / 1000);
        const dstImmutables = {
            orderHash: crypto.createHash('sha256').update(swapId).digest('hex'),
            hashlock: secretHash,
            maker: params.makerEthAddress,
            taker: params.takerEthAddress,
            token: params.tokenEth,
            amount: BigInt(params.amountEth) * BigInt(10 ** 18),
            safetyDeposit: BigInt(10 ** 16),
            timelocks: this.createTimelocks(0)
        };
        const tx = await resolverContract.initiateTezosToEthSwap(swapId, dstImmutables, now + 3600, params.makerTezosAddress, params.takerTezosAddress, BigInt(params.amountTezos) * BigInt(10 ** 6), tezosEscrowAddress, { value: dstImmutables.safetyDeposit });
        const receipt = await tx.wait();
        return {
            txHash: receipt.transactionHash,
            swapId,
            secret,
            secretHash: secretHash
        };
    }
    async createTezosEscrow(params) {
        if (!this.tezosEscrowAddress) {
            throw new Error('Tezos escrow contract address not provided');
        }
        const contract = await this.tezos.contract.at(this.tezosEscrowAddress);
        const timelock = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
        const secretHashBytes = Buffer.from(params.secretHash.replace('0x', ''), 'hex');
        const operation = await contract.methods.initiate(secretHashBytes, params.direction === 'eth-to-tezos' ? params.takerTezosAddress : params.makerTezosAddress, parseInt(params.amountTezos) * 1000000, timelock).send({
            amount: parseInt(params.amountTezos),
            mutez: false
        });
        await operation.confirmation();
        return this.tezosEscrowAddress;
    }
    async redeemTezosEscrow(secret) {
        if (!this.tezosEscrowAddress) {
            throw new Error('Tezos escrow contract address not provided');
        }
        const contract = await this.tezos.contract.at(this.tezosEscrowAddress);
        const secretBytes = Buffer.from(secret.replace('0x', ''), 'hex');
        const operation = await contract.methods.redeem(secretBytes).send();
        await operation.confirmation();
        return operation.hash;
    }
    async refundTezosEscrow() {
        if (!this.tezosEscrowAddress) {
            throw new Error('Tezos escrow contract address not provided');
        }
        const contract = await this.tezos.contract.at(this.tezosEscrowAddress);
        const operation = await contract.methods.refund(null).send();
        await operation.confirmation();
        return operation.hash;
    }
    async completeEthToTezosSwap(swapId, secret) {
        const resolverContract = new ethers_1.Contract(this.resolverAddress, this.getResolverABI(), this.ethSigner);
        const tx = await resolverContract.completeEthToTezosSwap(swapId, secret);
        const receipt = await tx.wait();
        return receipt.transactionHash;
    }
    async completeTezosToEthSwap(swapId, secret) {
        const resolverContract = new ethers_1.Contract(this.resolverAddress, this.getResolverABI(), this.ethSigner);
        const tx = await resolverContract.completeTezosToEthSwap(swapId, secret);
        const receipt = await tx.wait();
        return receipt.transactionHash;
    }
    async getSwapDetails(swapId) {
        const resolverContract = new ethers_1.Contract(this.resolverAddress, this.getResolverABI(), this.ethSigner);
        const swap = await resolverContract.swaps(swapId);
        const tezosData = await resolverContract.getTezosSwapData(swapId);
        return {
            ...swap,
            tezosEscrowAddress: tezosData.tezosEscrowAddress,
            amountTezos: tezosData.amountTezos
        };
    }
    createTimelocks(deployedAt) {
        const base = deployedAt || Math.floor(Date.now() / 1000);
        return {
            srcWithdrawal: base + 3600,
            srcPublicWithdrawal: base + 7200,
            srcCancellation: base + 14400,
            srcPublicCancellation: base + 21600
        };
    }
    getResolverABI() {
        return [
            'function initiateEthToTezosSwap(bytes32,tuple,tuple,bytes32,bytes32,uint256,uint256,bytes,string,string,uint256) payable',
            'function initiateTezosToEthSwap(bytes32,tuple,uint256,string,string,uint256,string) payable',
            'function completeEthToTezosSwap(bytes32,bytes32)',
            'function completeTezosToEthSwap(bytes32,bytes32)',
            'function swaps(bytes32) view returns (tuple)',
            'function getTezosSwapData(bytes32) view returns (string,uint256)',
            'function swapExists(bytes32) view returns (bool)'
        ];
    }
}
exports.TezosEthereumBridgeSDK = TezosEthereumBridgeSDK;
