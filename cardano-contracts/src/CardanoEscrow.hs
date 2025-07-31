{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeOperators #-}

module CardanoEscrow where

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

-- | Cardano escrow data types
data EscrowDatum = EscrowDatum
    { edOrderHash :: BuiltinByteString
    , edHashlock :: BuiltinByteString
    , edMaker :: PubKeyHash
    , edTaker :: PubKeyHash
    , edAmount :: Integer
    , edSafetyDeposit :: Integer
    , edWithdrawalStart :: POSIXTime
    , edWithdrawalEnd :: POSIXTime
    , edCancellationStart :: POSIXTime
    , edCancellationEnd :: POSIXTime
    , edSrcChainId :: Integer
    , edDstChainId :: Integer
    , edStatus :: Integer -- 0 = Active, 1 = Withdrawn, 2 = Cancelled
    }
    deriving stock (Generic, Show)
    deriving anyclass (ToJSON, FromJSON, ToSchema)

PlutusTx.makeLift ''EscrowDatum

data EscrowRedeemer
    = Withdraw BuiltinByteString -- secret
    | Cancel
    | Rescue
    deriving stock (Generic, Show)
    deriving anyclass (ToJSON, FromJSON, ToSchema)

PlutusTx.makeLift ''EscrowRedeemer

-- | Escrow validator
escrowValidator :: EscrowDatum -> EscrowRedeemer -> ScriptContext -> Bool
escrowValidator datum redeemer ctx = case redeemer of
    Withdraw secret -> validateWithdraw datum secret ctx
    Cancel -> validateCancel datum ctx
    Rescue -> validateRescue datum ctx

-- | Validate withdrawal with secret
validateWithdraw :: EscrowDatum -> BuiltinByteString -> ScriptContext -> Bool
validateWithdraw datum secret ctx =
    let
        info = scriptContextTxInfo ctx
        now = txInfoValidRange info
        withdrawalStart = datum.edWithdrawalStart
        withdrawalEnd = datum.edWithdrawalEnd
        status = datum.edStatus
        taker = datum.edTaker
        signer = txInfoSignatories info
        secretHash = Builtins.sha2_256 secret
    in
        -- Check status is active
        status == 0 &&
        -- Check time is in withdrawal period
        now `contains` (from $ withdrawalStart) &&
        now `contains` (to $ withdrawalEnd) &&
        -- Check secret hash matches
        secretHash == datum.edHashlock &&
        -- Check taker is signing
        taker `elem` signer

-- | Validate cancellation
validateCancel :: EscrowDatum -> ScriptContext -> Bool
validateCancel datum ctx =
    let
        info = scriptContextTxInfo ctx
        now = txInfoValidRange info
        cancellationStart = datum.edCancellationStart
        status = datum.edStatus
        maker = datum.edMaker
        signer = txInfoSignatories info
    in
        -- Check status is active
        status == 0 &&
        -- Check time is in cancellation period
        now `contains` (from $ cancellationStart) &&
        -- Check maker is signing
        maker `elem` signer

-- | Validate rescue (emergency function)
validateRescue :: EscrowDatum -> ScriptContext -> Bool
validateRescue datum ctx =
    let
        info = scriptContextTxInfo ctx
        now = txInfoValidRange info
        rescueDelay = 86400 :: Integer -- 24 hours
        rescueStart = datum.edWithdrawalEnd + rescueDelay
        taker = datum.edTaker
        signer = txInfoSignatories info
    in
        -- Check time is after rescue delay
        now `contains` (from $ rescueStart) &&
        -- Check taker is signing
        taker `elem` signer

-- | Typed validator
typedEscrowValidator :: TypedValidator EscrowDatum EscrowRedeemer
typedEscrowValidator = mkTypedValidator @EscrowDatum @EscrowRedeemer
    $$(PlutusTx.compile [|| escrowValidator ||])
    $$(PlutusTx.compile [|| wrap ||])
  where
    wrap = mkUntypedValidator @EscrowDatum @EscrowRedeemer

-- | Validator hash
escrowValidatorHash :: ValidatorHash
escrowValidatorHash = validatorHash typedEscrowValidator

-- | Create escrow datum
createEscrowDatum :: BuiltinByteString -> BuiltinByteString -> PubKeyHash -> PubKeyHash -> Integer -> Integer -> POSIXTime -> POSIXTime -> POSIXTime -> POSIXTime -> Integer -> Integer -> EscrowDatum
createEscrowDatum orderHash hashlock maker taker amount safetyDeposit withdrawalStart withdrawalEnd cancellationStart cancellationEnd srcChainId dstChainId =
    EscrowDatum
        { edOrderHash = orderHash
        , edHashlock = hashlock
        , edMaker = maker
        , edTaker = taker
        , edAmount = amount
        , edSafetyDeposit = safetyDeposit
        , edWithdrawalStart = withdrawalStart
        , edWithdrawalEnd = withdrawalEnd
        , edCancellationStart = cancellationStart
        , edCancellationEnd = cancellationEnd
        , edSrcChainId = srcChainId
        , edDstChainId = dstChainId
        , edStatus = 0 -- Active
        }

-- | Helper functions
contains :: POSIXTimeRange -> POSIXTimeRange -> Bool
contains outer inner = 
    let
        outerFrom = ivFrom $ unInterval outer
        outerTo = ivTo $ unInterval outer
        innerFrom = ivFrom $ unInterval inner
        innerTo = ivTo $ unInterval inner
    in
        case (outerFrom, outerTo, innerFrom, innerTo) of
            (LowerBound (Finite outerFromVal) _, UpperBound (Finite outerToVal) _, LowerBound (Finite innerFromVal) _, UpperBound (Finite innerToVal) _) ->
                outerFromVal <= innerFromVal && innerToVal <= outerToVal
            _ -> False

from :: POSIXTime -> POSIXTimeRange
from t = POSIXTimeRange $ Interval (LowerBound (Finite t) True) (UpperBound PosInf True)

to :: POSIXTime -> POSIXTimeRange
to t = POSIXTimeRange $ Interval (LowerBound NegInf True) (UpperBound (Finite t) True)