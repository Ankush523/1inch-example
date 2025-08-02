export interface TezosSwapParams {
    makerEthAddress: string;
    takerEthAddress: string;
    makerTezosAddress: string;
    takerTezosAddress: string;
    tokenEth: string;
    amountEth: string;
    amountTezos: string;
    secretHash?: string;
}
export interface TezosSwapResult {
    txHash: string;
    swapId: string;
    secret?: string;
    secretHash: string;
}
export declare class TezosEthereumBridgeSDK {
    private tezos;
    private ethProvider;
    private ethSigner;
    private resolverAddress;
    private tezosEscrowAddress?;
    private tezosResolverAddress?;
    constructor(tezosRpcUrl: string, tezosPrivateKey: string, ethRpcUrl: string, ethPrivateKey: string, resolverAddress: string, tezosEscrowAddress?: string, tezosResolverAddress?: string);
    generateSecret(): {
        secret: string;
        secretHash: string;
    };
    initiateEthToTezosSwap(params: TezosSwapParams): Promise<TezosSwapResult>;
    initiateTezosToEthSwap(params: TezosSwapParams): Promise<TezosSwapResult>;
    private createTezosEscrow;
    redeemTezosEscrow(secret: string): Promise<string>;
    refundTezosEscrow(): Promise<string>;
    completeEthToTezosSwap(swapId: string, secret: string): Promise<string>;
    completeTezosToEthSwap(swapId: string, secret: string): Promise<string>;
    getSwapDetails(swapId: string): Promise<any>;
    private createTimelocks;
    private getResolverABI;
}
