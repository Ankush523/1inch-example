// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from 'openzeppelin-contracts/contracts/access/Ownable.sol';
import {IERC20} from 'openzeppelin-contracts/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from 'solidity-utils/contracts/libraries/SafeERC20.sol';

import {IOrderMixin} from 'limit-order-protocol/contracts/interfaces/IOrderMixin.sol';
import {TakerTraits} from 'limit-order-protocol/contracts/libraries/TakerTraitsLib.sol';

import {IResolverExample} from '../lib/cross-chain-swap/contracts/interfaces/IResolverExample.sol';
import {RevertReasonForwarder} from '../lib/cross-chain-swap/lib/solidity-utils/contracts/libraries/RevertReasonForwarder.sol';
import {IEscrowFactory} from '../lib/cross-chain-swap/contracts/interfaces/IEscrowFactory.sol';
import {IBaseEscrow} from '../lib/cross-chain-swap/contracts/interfaces/IBaseEscrow.sol';
import {TimelocksLib, Timelocks} from '../lib/cross-chain-swap/contracts/libraries/TimelocksLib.sol';
import {Address, AddressLib} from 'solidity-utils/contracts/libraries/AddressLib.sol';
import {IEscrow} from '../lib/cross-chain-swap/contracts/interfaces/IEscrow.sol';
import {ImmutablesLib} from '../lib/cross-chain-swap/contracts/libraries/ImmutablesLib.sol';

/**
 * @title TezosEthereumResolver
 * @notice Cross-chain resolver for ETH<>Tezos atomic swaps
 * @dev Inherits from Ownable and adds Tezos-specific functionality
 */
contract TezosEthereumResolver is Ownable {
    using ImmutablesLib for IBaseEscrow.Immutables;
    using TimelocksLib for Timelocks;
    using SafeERC20 for IERC20;
    using AddressLib for Address;

    error InvalidLength();
    error LengthMismatch();
    error InvalidSwapData();
    error SwapAlreadyExists();
    error SwapNotFound();
    error InvalidTezosAddress();

    // Tezos-specific constants
    uint8 public constant SWAP_ETH_TO_TEZOS = 3;
    uint8 public constant SWAP_TEZOS_TO_ETH = 4;

    // Tezos address format validation pattern
    bytes1 public constant TEZOS_ADDRESS_PREFIX_TZ1 = 0x06;
    bytes1 public constant TEZOS_ADDRESS_PREFIX_TZ2 = 0x06;
    bytes1 public constant TEZOS_ADDRESS_PREFIX_TZ3 = 0x06;

    /// @notice Cross-chain swap metadata
    struct CrossChainSwap {
        bytes32 swapId; // Unique swap identifier
        uint8 direction; // 3 = ETH->Tezos, 4 = Tezos->ETH
        bytes32 orderHash; // Ethereum order hash
        address ethEscrowAddress; // Ethereum escrow contract address
        string cardanoEscrowId; // Reused field for Tezos escrow ID
        address makerEthAddress; // Ethereum maker address
        address takerEthAddress; // Ethereum taker address
        string makerCardanoAddress; // Reused field for Tezos maker address
        string takerCardanoAddress; // Reused field for Tezos taker address
        uint256 amountEth; // Amount on Ethereum side
        uint256 amountCardano; // Reused field for Tezos amount
        bytes32 secretHash; // Hash of the secret
        uint256 createdAt; // Creation timestamp
        uint8 status; // 0 = Active, 1 = Completed, 2 = Cancelled
    }

    // Events specific to Tezos swaps
    event TezosSwapInitiated(
        bytes32 indexed swapId,
        uint8 direction,
        address indexed maker,
        address indexed taker,
        string makerTezosAddress,
        string takerTezosAddress,
        uint256 amountEth,
        uint256 amountTezos,
        bytes32 secretHash
    );

    event TezosSwapCompleted(bytes32 indexed swapId, bytes32 secret, address indexed recipient);

    event TezosSwapCancelled(bytes32 indexed swapId, address indexed refundRecipient);

    IEscrowFactory private immutable _FACTORY;
    IOrderMixin private immutable _LOP;

    /// @notice Mapping of swap ID to swap data
    mapping(bytes32 => CrossChainSwap) public swaps;

    /// @notice Mapping to track existing swaps
    mapping(bytes32 => bool) public swapExists;

    /// @notice Array to track all swap IDs
    bytes32[] public allSwapIds;

    constructor(IEscrowFactory factory, IOrderMixin lop, address initialOwner) Ownable(initialOwner) {
        _FACTORY = factory;
        _LOP = lop;
    }

    receive() external payable {} // solhint-disable-line no-empty-blocks

    /**
     * @notice Initiate ETH to Tezos swap by deploying source escrow
     * @param swapId Unique identifier for the swap
     * @param immutables The immutables of the escrow contract
     * @param order Order quote to fill
     * @param r R component of signature
     * @param vs VS component of signature
     * @param amount Taker amount to fill
     * @param takerTraits Taker traits
     * @param args Arguments for the order
     * @param makerTezosAddress Maker's Tezos address
     * @param takerTezosAddress Taker's Tezos address
     * @param amountTezos Amount on Tezos side (in mutez)
     */
    function initiateEthToTezosSwap(
        bytes32 swapId,
        IBaseEscrow.Immutables calldata immutables,
        IOrderMixin.Order calldata order,
        bytes32 r,
        bytes32 vs,
        uint256 amount,
        TakerTraits takerTraits,
        bytes calldata args,
        string calldata makerTezosAddress,
        string calldata takerTezosAddress,
        uint256 amountTezos
    ) external payable onlyOwner {
        require(!swapExists[swapId], 'Swap already exists');
        require(bytes(makerTezosAddress).length > 0, 'Invalid maker Tezos address');
        require(bytes(takerTezosAddress).length > 0, 'Invalid taker Tezos address');
        require(_isValidTezosAddress(makerTezosAddress), 'Invalid maker Tezos address format');
        require(_isValidTezosAddress(takerTezosAddress), 'Invalid taker Tezos address format');
        require(amountTezos > 0, 'Tezos amount must be positive');

        // Deploy source escrow (same as original deploySrc)
        IBaseEscrow.Immutables memory immutablesMem = immutables;
        immutablesMem.timelocks = TimelocksLib.setDeployedAt(immutables.timelocks, block.timestamp);
        address computed = _FACTORY.addressOfEscrowSrc(immutablesMem);

        (bool success, ) = address(computed).call{value: immutablesMem.safetyDeposit}('');
        if (!success) revert IBaseEscrow.NativeTokenSendingFailure();

        // _ARGS_HAS_TARGET = 1 << 251
        takerTraits = TakerTraits.wrap(TakerTraits.unwrap(takerTraits) | uint256(1 << 251));
        bytes memory argsMem = abi.encodePacked(computed, args);
        _LOP.fillOrderArgs(order, r, vs, amount, takerTraits, argsMem);

        // Store swap metadata
        CrossChainSwap memory swap = CrossChainSwap({
            swapId: swapId,
            direction: SWAP_ETH_TO_TEZOS,
            orderHash: immutables.orderHash,
            ethEscrowAddress: computed,
            cardanoEscrowId: '', // Not used for Tezos
            makerEthAddress: immutables.maker.get(),
            takerEthAddress: immutables.taker.get(),
            makerCardanoAddress: makerTezosAddress, // Reuse field for Tezos
            takerCardanoAddress: takerTezosAddress, // Reuse field for Tezos
            amountEth: amount,
            amountCardano: amountTezos, // Reuse field for Tezos
            secretHash: immutables.hashlock,
            createdAt: block.timestamp,
            status: 0 // Active
        });

        swaps[swapId] = swap;
        swapExists[swapId] = true;
        allSwapIds.push(swapId);

        emit TezosSwapInitiated(
            swapId,
            SWAP_ETH_TO_TEZOS,
            immutables.maker.get(),
            immutables.taker.get(),
            makerTezosAddress,
            takerTezosAddress,
            amount,
            amountTezos,
            immutables.hashlock
        );
    }

    /**
     * @notice Initiate Tezos to ETH swap by deploying destination escrow
     * @param swapId Unique identifier for the swap
     * @param dstImmutables The immutables of the destination escrow contract
     * @param srcCancellationTimestamp The start of the cancellation period for the source chain
     * @param makerTezosAddress Maker's Tezos address
     * @param takerTezosAddress Taker's Tezos address
     * @param amountTezos Amount on Tezos side (in mutez)
     * @param tezosEscrowAddress Tezos escrow contract address
     */
    function initiateTezosToEthSwap(
        bytes32 swapId,
        IBaseEscrow.Immutables calldata dstImmutables,
        uint256 srcCancellationTimestamp,
        string calldata makerTezosAddress,
        string calldata takerTezosAddress,
        uint256 amountTezos,
        string calldata tezosEscrowAddress
    ) external payable onlyOwner {
        require(!swapExists[swapId], 'Swap already exists');
        require(bytes(makerTezosAddress).length > 0, 'Invalid maker Tezos address');
        require(bytes(takerTezosAddress).length > 0, 'Invalid taker Tezos address');
        require(_isValidTezosAddress(makerTezosAddress), 'Invalid maker Tezos address format');
        require(_isValidTezosAddress(takerTezosAddress), 'Invalid taker Tezos address format');
        require(bytes(tezosEscrowAddress).length > 0, 'Invalid Tezos escrow address');

        // Deploy destination escrow
        address dstEscrow = _FACTORY.addressOfEscrowDst(dstImmutables);
        _FACTORY.createDstEscrow{value: msg.value}(dstImmutables, srcCancellationTimestamp);

        // Store swap metadata
        CrossChainSwap memory swap = CrossChainSwap({
            swapId: swapId,
            direction: SWAP_TEZOS_TO_ETH,
            orderHash: dstImmutables.orderHash,
            ethEscrowAddress: dstEscrow,
            cardanoEscrowId: tezosEscrowAddress, // Reuse field for Tezos
            makerEthAddress: dstImmutables.maker.get(),
            takerEthAddress: dstImmutables.taker.get(),
            makerCardanoAddress: makerTezosAddress, // Reuse field for Tezos
            takerCardanoAddress: takerTezosAddress, // Reuse field for Tezos
            amountEth: dstImmutables.amount,
            amountCardano: amountTezos, // Reuse field for Tezos
            secretHash: dstImmutables.hashlock,
            createdAt: block.timestamp,
            status: 0 // Active
        });

        swaps[swapId] = swap;
        swapExists[swapId] = true;
        allSwapIds.push(swapId);

        emit TezosSwapInitiated(
            swapId,
            SWAP_TEZOS_TO_ETH,
            dstImmutables.maker.get(),
            dstImmutables.taker.get(),
            makerTezosAddress,
            takerTezosAddress,
            dstImmutables.amount,
            amountTezos,
            dstImmutables.hashlock
        );
    }

    /**
     * @notice Complete ETH to Tezos swap by revealing the secret
     * @param swapId The swap identifier
     * @param secret The secret that unlocks both escrows
     */
    function completeEthToTezosSwap(bytes32 swapId, bytes32 secret) external {
        require(swapExists[swapId], 'Swap does not exist');

        CrossChainSwap storage swap = swaps[swapId];
        require(swap.status == 0, 'Swap is not active');
        require(swap.direction == SWAP_ETH_TO_TEZOS, 'Not an ETH to Tezos swap');
        require(keccak256(abi.encodePacked(secret)) == swap.secretHash, 'Invalid secret');

        // Mark swap as completed
        swap.status = 1;

        emit TezosSwapCompleted(swapId, secret, address(0));
    }

    /**
     * @notice Complete Tezos to ETH swap by revealing the secret
     * @param swapId The swap identifier
     * @param secret The secret that unlocks both escrows
     */
    function completeTezosToEthSwap(bytes32 swapId, bytes32 secret) external {
        require(swapExists[swapId], 'Swap does not exist');

        CrossChainSwap storage swap = swaps[swapId];
        require(swap.status == 0, 'Swap is not active');
        require(swap.direction == SWAP_TEZOS_TO_ETH, 'Not a Tezos to ETH swap');
        require(keccak256(abi.encodePacked(secret)) == swap.secretHash, 'Invalid secret');

        // Mark swap as completed
        swap.status = 1;

        emit TezosSwapCompleted(swapId, secret, address(0));
    }

    /**
     * @notice Update Tezos escrow address for a swap
     * @param swapId The swap identifier
     * @param tezosEscrowAddress The Tezos escrow contract address
     */
    function updateTezosEscrowAddress(bytes32 swapId, string calldata tezosEscrowAddress) external onlyOwner {
        require(swapExists[swapId], 'Swap does not exist');
        require(bytes(tezosEscrowAddress).length > 0, 'Invalid Tezos escrow address');

        swaps[swapId].cardanoEscrowId = tezosEscrowAddress; // Reuse field for Tezos escrow address

        emit TezosSwapCompleted(swapId, bytes32(0), address(0)); // Updated event
    }

    /**
     * @notice Get Tezos-specific swap data
     * @param swapId The swap identifier
     * @return tezosEscrowAddress The Tezos escrow contract address
     * @return amountTezos The amount on Tezos side
     */
    function getTezosSwapData(
        bytes32 swapId
    ) external view returns (string memory tezosEscrowAddress, uint256 amountTezos) {
        CrossChainSwap memory swap = swaps[swapId];
        return (swap.cardanoEscrowId, swap.amountCardano); // Reuse fields for Tezos data
    }

    /**
     * @notice Validate Tezos address format
     * @param tezosAddress The Tezos address to validate
     * @return true if valid, false otherwise
     */
    function _isValidTezosAddress(string memory tezosAddress) private pure returns (bool) {
        bytes memory addressBytes = bytes(tezosAddress);

        // Check minimum length (Tezos addresses are typically 36 characters)
        if (addressBytes.length < 36 || addressBytes.length > 36) {
            return false;
        }

        // Check prefix (tz1, tz2, tz3, or KT1 for contracts)
        if (
            (addressBytes[0] == 't' &&
                addressBytes[1] == 'z' &&
                (addressBytes[2] == '1' || addressBytes[2] == '2' || addressBytes[2] == '3')) ||
            (addressBytes[0] == 'K' && addressBytes[1] == 'T' && addressBytes[2] == '1')
        ) {
            return true;
        }

        return false;
    }

    /**
     * @notice Get all Tezos swaps for debugging
     * @return Array of all swap IDs with Tezos direction
     */
    function getAllTezosSwaps() external view returns (bytes32[] memory) {
        bytes32[] memory tezosSwapIds = new bytes32[](allSwapIds.length);
        uint256 count = 0;

        for (uint256 i = 0; i < allSwapIds.length; i++) {
            bytes32 swapId = allSwapIds[i];
            CrossChainSwap memory swap = swaps[swapId];
            if (swap.direction == SWAP_ETH_TO_TEZOS || swap.direction == SWAP_TEZOS_TO_ETH) {
                tezosSwapIds[count] = swapId;
                count++;
            }
        }

        // Trim array to actual size
        bytes32[] memory result = new bytes32[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = tezosSwapIds[i];
        }

        return result;
    }
}
