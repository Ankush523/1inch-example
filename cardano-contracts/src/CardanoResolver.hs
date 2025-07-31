{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeOperators #-}

module CardanoResolver where

import qualified PlutusTx
import PlutusTx.Prelude
import qualified PlutusTx.Builtins as Builtins
import qualified PlutusTx.AssocMap as Map

import Ledger
import Ledger.Ada as Ada
import Ledger.Value as Value
import Ledger.Tx (TxOutTx(..))
import Ledger.Typed.Scripts
import Ledger.Typed.Scripts.Validators
import Ledger.Typed.Tx

import qualified Ledger.Scripts as Scripts
import qualified Ledger.Typed.Scripts as Scripts

import Data.Aeson (FromJSON, ToJSON)
import GHC.Generics (Generic)
import Schema (ToSchema)

import CardanoEscrow

-- | Swap direction constants
swapEthToCardano :: Integer
swapEthToCardano = 0

swapCardanoToEth :: Integer
swapCardanoToEth = 1

-- | Swap metadata for cross-chain coordination
data SwapMetadata = SwapMetadata
    { smSwapId :: BuiltinByteString
    , smDirection :: Integer -- 0 = ETH->Cardano, 1 = Cardano->ETH
    , smEthOrderHash :: BuiltinByteString
    , smEthEscrowAddress :: BuiltinByteString
    , smCardanoEscrowId :: BuiltinByteString
    , smMakerEthAddress :: BuiltinByteString
    , smTakerEthAddress :: BuiltinByteString
    , smMakerCardanoAddress :: PubKeyHash
    , smTakerCardanoAddress :: PubKeyHash
    , smAmountEth :: Integer
    , smAmountCardano :: Integer
    , smSecretHash :: BuiltinByteString
    , smCreatedAt :: POSIXTime
    , smStatus :: Integer -- 0 = Active, 1 = Completed, 2 = Cancelled
    }
    deriving stock (Generic, Show)
    deriving anyclass (ToJSON, FromJSON, ToSchema)

PlutusTx.makeLift ''SwapMetadata

-- | Resolver datum
data ResolverDatum = ResolverDatum
    { rdSwaps :: [SwapMetadata]
    , rdNextSwapId :: Integer
    }
    deriving stock (Generic, Show)
    deriving anyclass (ToJSON, FromJSON, ToSchema)

PlutusTx.makeLift ''ResolverDatum

-- | Resolver redeemer
data ResolverRedeemer
    = InitiateEthToCardanoSwap SwapMetadata
    | InitiateCardanoToEthSwap SwapMetadata
    | CompleteSwap BuiltinByteString BuiltinByteString -- swapId, secret
    | CancelSwap BuiltinByteString
    deriving stock (Generic, Show)
    deriving anyclass (ToJSON, FromJSON, ToSchema)

PlutusTx.makeLift ''ResolverRedeemer

-- | Resolver validator
resolverValidator :: ResolverDatum -> ResolverRedeemer -> ScriptContext -> Bool
resolverValidator datum redeemer ctx = case redeemer of
    InitiateEthToCardanoSwap swapMeta -> validateInitiateEthToCardanoSwap datum swapMeta ctx
    InitiateCardanoToEthSwap swapMeta -> validateInitiateCardanoToEthSwap datum swapMeta ctx
    CompleteSwap swapId secret -> validateCompleteSwap datum swapId secret ctx
    CancelSwap swapId -> validateCancelSwap datum swapId ctx

-- | Validate ETH to Cardano swap initiation
validateInitiateEthToCardanoSwap :: ResolverDatum -> SwapMetadata -> ScriptContext -> Bool
validateInitiateEthToCardanoSwap datum swapMeta ctx =
    let
        info = scriptContextTxInfo ctx
        signer = txInfoSignatories info
        maker = swapMeta.smMakerCardanoAddress
        taker = swapMeta.smTakerCardanoAddress
        direction = swapMeta.smDirection
        status = swapMeta.smStatus
    in
        -- Check direction is correct
        direction == swapEthToCardano &&
        -- Check status is active
        status == 0 &&
        -- Check maker is signing
        maker `elem` signer &&
        -- Check swap doesn't already exist
        not (swapExists datum swapMeta.smSwapId)

-- | Validate Cardano to ETH swap initiation
validateInitiateCardanoToEthSwap :: ResolverDatum -> SwapMetadata -> ScriptContext -> Bool
validateInitiateCardanoToEthSwap datum swapMeta ctx =
    let
        info = scriptContextTxInfo ctx
        signer = txInfoSignatories info
        maker = swapMeta.smMakerCardanoAddress
        taker = swapMeta.smTakerCardanoAddress
        direction = swapMeta.smDirection
        status = swapMeta.smStatus
    in
        -- Check direction is correct
        direction == swapCardanoToEth &&
        -- Check status is active
        status == 0 &&
        -- Check maker is signing
        maker `elem` signer &&
        -- Check swap doesn't already exist
        not (swapExists datum swapMeta.smSwapId)

-- | Validate swap completion
validateCompleteSwap :: ResolverDatum -> BuiltinByteString -> BuiltinByteString -> ScriptContext -> Bool
validateCompleteSwap datum swapId secret ctx =
    let
        info = scriptContextTxInfo ctx
        signer = txInfoSignatories info
        swap = findSwap datum swapId
        taker = swap.smTakerCardanoAddress
        secretHash = Builtins.sha2_256 secret
    in
        case swap of
            Just s ->
                -- Check taker is signing
                taker `elem` signer &&
                -- Check secret hash matches
                secretHash == s.smSecretHash &&
                -- Check status is active
                s.smStatus == 0
            Nothing -> False

-- | Validate swap cancellation
validateCancelSwap :: ResolverDatum -> BuiltinByteString -> ScriptContext -> Bool
validateCancelSwap datum swapId ctx =
    let
        info = scriptContextTxInfo ctx
        signer = txInfoSignatories info
        swap = findSwap datum swapId
        maker = swap.smMakerCardanoAddress
    in
        case swap of
            Just s ->
                -- Check maker is signing
                maker `elem` signer &&
                -- Check status is active
                s.smStatus == 0
            Nothing -> False

-- | Helper functions
swapExists :: ResolverDatum -> BuiltinByteString -> Bool
swapExists datum swapId = 
    case findSwap datum swapId of
        Just _ -> True
        Nothing -> False

findSwap :: ResolverDatum -> BuiltinByteString -> Maybe SwapMetadata
findSwap datum swapId = 
    foldr (\swap acc -> 
        if swap.smSwapId == swapId then Just swap else acc
    ) Nothing datum.rdSwaps

-- | Typed validator
typedResolverValidator :: TypedValidator ResolverDatum ResolverRedeemer
typedResolverValidator = mkTypedValidator @ResolverDatum @ResolverRedeemer
    $$(PlutusTx.compile [|| resolverValidator ||])
    $$(PlutusTx.compile [|| wrap ||])
  where
    wrap = mkUntypedValidator @ResolverDatum @ResolverRedeemer

-- | Validator hash
resolverValidatorHash :: ValidatorHash
resolverValidatorHash = validatorHash typedResolverValidator

-- | Create swap metadata
createSwapMetadata :: BuiltinByteString -> Integer -> BuiltinByteString -> BuiltinByteString -> BuiltinByteString -> PubKeyHash -> PubKeyHash -> Integer -> Integer -> BuiltinByteString -> POSIXTime -> SwapMetadata
createSwapMetadata swapId direction ethOrderHash ethEscrowAddress cardanoEscrowId makerEthAddress takerEthAddress makerCardanoAddress takerCardanoAddress amountEth amountCardano secretHash createdAt =
    SwapMetadata
        { smSwapId = swapId
        , smDirection = direction
        , smEthOrderHash = ethOrderHash
        , smEthEscrowAddress = ethEscrowAddress
        , smCardanoEscrowId = cardanoEscrowId
        , smMakerEthAddress = makerEthAddress
        , smTakerEthAddress = takerEthAddress
        , smMakerCardanoAddress = makerCardanoAddress
        , smTakerCardanoAddress = takerCardanoAddress
        , smAmountEth = amountEth
        , smAmountCardano = amountCardano
        , smSecretHash = secretHash
        , smCreatedAt = createdAt
        , smStatus = 0 -- Active
        }

-- | Create resolver datum
createResolverDatum :: [SwapMetadata] -> Integer -> ResolverDatum
createResolverDatum swaps nextId =
    ResolverDatum
        { rdSwaps = swaps
        , rdNextSwapId = nextId
        }