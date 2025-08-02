# 🚀 Step-by-Step Guide: Execute Real ETH<>Cardano Token Swaps

## Prerequisites ✅

Before starting, ensure you have:

1. **Sufficient ETH Balance**: At least 0.1 ETH on Ethereum Sepolia testnet for gas fees and safety deposits
2. **Cardano Testnet Setup**: Access to Cardano Preprod testnet with ADA for testing
3. **Environment Variables**: Properly configured `.env` file
4. **Deployed Contracts**: CardanoEthereumResolver deployed at `0xE922911704Ad76A2044063620aDDa18571A8F8Ed`

## Step 1: Prepare Your Environment 🔧

### 1.1 Check Your Balances
```bash
# Check ETH balance
npx tsx -e "
import { JsonRpcProvider, Wallet, formatEther } from 'ethers';
const provider = new JsonRpcProvider(process.env.ETH_TESTNET_RPC);
const wallet = new Wallet(process.env.DEPLOYER_PRIVATE_KEY, provider);
provider.getBalance(wallet.address).then(b => console.log('ETH Balance:', formatEther(b)));
"
```

### 1.2 Verify Contract Deployment
```bash
# Verify resolver contract is deployed
npx tsx -e "
import { JsonRpcProvider } from 'ethers';
const provider = new JsonRpcProvider(process.env.ETH_TESTNET_RPC);
provider.getCode('0xE922911704Ad76A2044063620aDDa18571A8F8Ed').then(code => 
  console.log('Contract deployed:', code !== '0x')
);
"
```

## Step 2: Create a Real Cross-Chain Order 📝

### 2.1 Choose Your Swap Parameters
Decide on:
- **ETH Amount**: How much ETH to swap (e.g., 0.01 ETH)
- **Cardano Amount**: How much ADA to receive (e.g., 25 ADA)
- **Cardano Addresses**: Valid Cardano testnet addresses for maker and taker
- **Token Type**: ETH or ERC20 token address

### 2.2 Get Real Cardano Addresses
For testing, you need actual Cardano Preprod testnet addresses:
```bash
# Example Cardano testnet addresses (replace with your own)
MAKER_CARDANO="addr_test1qr2s8wz3..."  # Your Cardano address
TAKER_CARDANO="addr_test1qs8f7km9..."  # Recipient Cardano address
```

## Step 3: Create 1inch Limit Order 📊

### 3.1 Generate Order Data
You need to create a valid 1inch limit order with:
- Salt (unique identifier)
- Maker address (your ETH address)
- Taker address (swap counterparty)
- Making amount (ETH amount)
- Taking amount (will be fulfilled on Cardano)
- Proper signature

### 3.2 Sign the Order
The order must be signed with your private key according to 1inch protocol standards.

## Step 4: Prepare Escrow Immutables 🔐

### 4.1 Create Escrow Parameters
```typescript
const immutables = {
    orderHash: orderHash,           // Hash of the 1inch order
    hashlock: secretHash,           // Hash of the secret for atomic swap
    maker: makerAddress,            // Your ETH address
    taker: takerAddress,            // Counterparty ETH address
    token: tokenAddress,            // Token to swap (ETH = 0x000...)
    amount: swapAmount,             // Amount to swap
    safetyDeposit: parseEther('0.001'), // Safety deposit
    timelocks: {
        srcWithdrawal: timestamp + 3600,      // 1 hour
        srcPublicWithdrawal: timestamp + 7200, // 2 hours
        srcCancellation: timestamp + 14400,    // 4 hours
        srcPublicCancellation: timestamp + 21600 // 6 hours
    }
}
```

## Step 5: Execute the ETH->Cardano Swap 🔄

### 5.1 Call initiateEthToCardanoSwap
```typescript
const tx = await resolver.initiateEthToCardanoSwap(
    swapId,                    // Unique swap identifier
    immutables,                // Escrow parameters
    order,                     // 1inch order data
    r,                         // Signature R component
    vs,                        // Signature VS component
    amount,                    // Amount to fill
    takerTraits,               // Taker configuration
    args,                      // Additional arguments
    makerCardanoAddress,       // Your Cardano address
    takerCardanoAddress,       // Recipient Cardano address
    amountCardano,             // ADA amount
    { value: safetyDeposit }   // ETH safety deposit
)
```

### 5.2 Wait for Transaction Confirmation
```bash
# Monitor the transaction
echo "Transaction hash: $TX_HASH"
# Check on Etherscan Sepolia
```

## Step 6: Set Up Cardano Escrow 🏛️

### 6.1 Create Cardano Escrow Contract
On Cardano side, you need to:
1. Deploy the Cardano escrow contract with matching parameters
2. Lock the ADA amount with the same secret hash
3. Set appropriate timelock conditions

### 6.2 Link Escrows
Update the swap metadata to include the Cardano escrow ID:
```typescript
await resolver.updateCardanoEscrowId(swapId, cardanoEscrowId)
```

## Step 7: Complete the Swap 🎯

### 7.1 Reveal Secret on Cardano
The taker reveals the secret on Cardano to claim the ADA:
```bash
# Cardano transaction to reveal secret and claim ADA
cardano-cli transaction build-raw ...
```

### 7.2 Claim ETH with Revealed Secret
Once the secret is revealed on Cardano, use it to claim ETH from the Ethereum escrow:
```typescript
await escrowContract.withdraw(secret, immutables)
```

## Step 8: Monitor and Verify ✅

### 8.1 Check Swap Status
```typescript
const swapData = await resolver.swaps(swapId)
console.log('Swap status:', swapData.status)
console.log('ETH escrow:', swapData.ethEscrowAddress)
console.log('Cardano escrow:', swapData.cardanoEscrowId)
```

### 8.2 Verify Balances
Check that tokens were transferred correctly on both chains.

## 🚨 Important Notes

### Security Considerations:
1. **Test with small amounts first**
2. **Use proper timelock settings**
3. **Verify all addresses and amounts**
4. **Keep secrets secure until reveal time**

### Gas Costs:
- Contract deployment: ~0.02-0.05 ETH
- Swap initiation: ~0.005-0.01 ETH
- Safety deposits: ~0.001 ETH per escrow

### Timelock Strategy:
- Set sufficient time for Cardano transactions
- Account for network congestion
- Plan for manual intervention if needed

## 🔧 Troubleshooting

### Common Issues:
1. **Insufficient gas**: Increase gas limit
2. **Invalid signatures**: Verify order signing
3. **Timelock conflicts**: Adjust timelock parameters
4. **Cardano connectivity**: Check Cardano node status

### Recovery Options:
- Cancel swap before timelock expires
- Reclaim safety deposits after timeout
- Use emergency withdrawal functions

## 📞 Need Help?

If you encounter issues:
1. Check the transaction logs for error messages
2. Verify all parameters match between chains
3. Ensure sufficient balances for gas and deposits
4. Test with smaller amounts first

---

**Ready to execute real swaps? Start with Step 1 and work through each step carefully!** 🚀
