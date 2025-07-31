// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "solidity-utils/contracts/libraries/SafeERC20.sol";

import {IOrderMixin} from "limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import {TakerTraits} from "limit-order-protocol/contracts/libraries/TakerTraitsLib.sol";

import {IResolverExample} from "../lib/cross-chain-swap/contracts/interfaces/IResolverExample.sol";
import {RevertReasonForwarder} from "../lib/cross-chain-swap/lib/solidity-utils/contracts/libraries/RevertReasonForwarder.sol";
import {IEscrowFactory} from "../lib/cross-chain-swap/contracts/interfaces/IEscrowFactory.sol";
import {IBaseEscrow} from "../lib/cross-chain-swap/contracts/interfaces/IBaseEscrow.sol";
import {TimelocksLib, Timelocks} from "../lib/cross-chain-swap/contracts/libraries/TimelocksLib.sol";
import {Address, AddressLib} from "solidity-utils/contracts/libraries/AddressLib.sol";
import {IEscrow} from "../lib/cross-chain-swap/contracts/interfaces/IEscrow.sol";
import {ImmutablesLib} from "../lib/cross-chain-swap/contracts/libraries/ImmutablesLib.sol";

/**
 * @title Enhanced Resolver for Ethereum-Cardano Cross-chain Swaps
 * @dev Extends the base resolver to support bidirectional swaps with Cardano blockchain
 * @custom:security-contact security@1inch.io
 */
contract CardanoEthereumResolver is Ownable {
    using ImmutablesLib for IBaseEscrow.Immutables;
    using TimelocksLib for Timelocks;
    using SafeERC20 for IERC20;
    using AddressLib for Address;

    error InvalidLength();
    error LengthMismatch();
    error InvalidSwapData();
    error SwapAlreadyExists();
    error SwapNotFound();
    error InvalidCardanoAddress();

    /// @notice Swap direction constants
    uint8 public constant SWAP_ETH_TO_CARDANO = 0;
    uint8 public constant SWAP_CARDANO_TO_ETH = 1;

    /// @notice Cross-chain swap metadata
    struct CrossChainSwap {
        bytes32 swapId;                    // Unique swap identifier
        uint8 direction;                   // 0 = ETH->Cardano, 1 = Cardano->ETH
        bytes32 orderHash;                 // Ethereum order hash
        address ethEscrowAddress;          // Ethereum escrow contract address
        string cardanoEscrowId;            // Cardano escrow ID (as string)
        address makerEthAddress;           // Ethereum maker address
        address takerEthAddress;           // Ethereum taker address
        string makerCardanoAddress;        // Cardano maker address
        string takerCardanoAddress;        // Cardano taker address
        uint256 amountEth;                 // Amount on Ethereum side
        uint256 amountCardano;             // Amount on Cardano side (in Lovelace)
        bytes32 secretHash;                // Hash of the secret
        uint256 createdAt;                 // Creation timestamp
        uint8 status;                      // 0 = Active, 1 = Completed, 2 = Cancelled
    }

    /// @notice Events
    event CardanoSwapInitiated(
        bytes32 indexed swapId,
        uint8 direction,
        address indexed makerEth,
        address indexed takerEth,
        string makerCardano,
        string takerCardano,
        uint256 amountEth,
        uint256 amountCardano,
        bytes32 secretHash
    );

    event CardanoSwapCompleted(
        bytes32 indexed swapId,
        bytes32 secret,
        address indexed recipient
    );

    event CardanoSwapCancelled(
        bytes32 indexed swapId,
        address indexed refundRecipient
    );

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
     * @notice Initiate ETH to Cardano swap by deploying source escrow
     * @param swapId Unique identifier for the swap
     * @param immutables The immutables of the escrow contract
     * @param order Order quote to fill
     * @param r R component of signature
     * @param vs VS component of signature
     * @param amount Taker amount to fill
     * @param takerTraits Taker traits
     * @param args Arguments for the order
     * @param makerCardanoAddress Maker's Cardano address
     * @param takerCardanoAddress Taker's Cardano address
     * @param amountCardano Amount on Cardano side
     */
    function initiateEthToCardanoSwap(
        bytes32 swapId,
        IBaseEscrow.Immutables calldata immutables,
        IOrderMixin.Order calldata order,
        bytes32 r,
        bytes32 vs,
        uint256 amount,
        TakerTraits takerTraits,
        bytes calldata args,
        string calldata makerCardanoAddress,
        string calldata takerCardanoAddress,
        uint256 amountCardano
    ) external payable onlyOwner {
        require(!swapExists[swapId], "Swap already exists");
        require(bytes(makerCardanoAddress).length > 0, "Invalid maker Cardano address");
        require(bytes(takerCardanoAddress).length > 0, "Invalid taker Cardano address");

        // Deploy source escrow (same as original deploySrc)
        IBaseEscrow.Immutables memory immutablesMem = immutables;
        immutablesMem.timelocks = TimelocksLib.setDeployedAt(immutables.timelocks, block.timestamp);
        address computed = _FACTORY.addressOfEscrowSrc(immutablesMem);

        (bool success,) = address(computed).call{value: immutablesMem.safetyDeposit}("");
        if (!success) revert IBaseEscrow.NativeTokenSendingFailure();

        // _ARGS_HAS_TARGET = 1 << 251
        takerTraits = TakerTraits.wrap(TakerTraits.unwrap(takerTraits) | uint256(1 << 251));
        bytes memory argsMem = abi.encodePacked(computed, args);
        _LOP.fillOrderArgs(order, r, vs, amount, takerTraits, argsMem);

        // Store swap metadata
        CrossChainSwap memory swap = CrossChainSwap({
            swapId: swapId,
            direction: SWAP_ETH_TO_CARDANO,
            orderHash: immutables.orderHash,
            ethEscrowAddress: computed,
            cardanoEscrowId: "", // Will be set when Cardano escrow is created
            makerEthAddress: immutables.maker.get(),
            takerEthAddress: immutables.taker.get(),
            makerCardanoAddress: makerCardanoAddress,
            takerCardanoAddress: takerCardanoAddress,
            amountEth: amount,
            amountCardano: amountCardano,
            secretHash: immutables.hashlock,
            createdAt: block.timestamp,
            status: 0 // Active
        });

        swaps[swapId] = swap;
        swapExists[swapId] = true;
        allSwapIds.push(swapId);

        emit CardanoSwapInitiated(
            swapId,
            SWAP_ETH_TO_CARDANO,
            immutables.maker.get(),
            immutables.taker.get(),
            makerCardanoAddress,
            takerCardanoAddress,
            amount,
            amountCardano,
            immutables.hashlock
        );
    }

    /**
     * @notice Initiate Cardano to ETH swap by deploying destination escrow
     * @param swapId Unique identifier for the swap
     * @param dstImmutables The immutables of the destination escrow contract
     * @param srcCancellationTimestamp The start of the cancellation period for the source chain
     * @param makerCardanoAddress Maker's Cardano address
     * @param takerCardanoAddress Taker's Cardano address
     * @param amountCardano Amount on Cardano side
     */
    function initiateCardanoToEthSwap(
        bytes32 swapId,
        IBaseEscrow.Immutables calldata dstImmutables,
        uint256 srcCancellationTimestamp,
        string calldata makerCardanoAddress,
        string calldata takerCardanoAddress,
        uint256 amountCardano,
        string calldata cardanoEscrowId
    ) external onlyOwner payable {
        require(!swapExists[swapId], "Swap already exists");
        require(bytes(makerCardanoAddress).length > 0, "Invalid maker Cardano address");
        require(bytes(takerCardanoAddress).length > 0, "Invalid taker Cardano address");

        // Deploy destination escrow
        address dstEscrow = _FACTORY.addressOfEscrowDst(dstImmutables);
        _FACTORY.createDstEscrow{value: msg.value}(dstImmutables, srcCancellationTimestamp);

        // Store swap metadata
        CrossChainSwap memory swap = CrossChainSwap({
            swapId: swapId,
            direction: SWAP_CARDANO_TO_ETH,
            orderHash: dstImmutables.orderHash,
            ethEscrowAddress: dstEscrow,
            cardanoEscrowId: cardanoEscrowId,
            makerEthAddress: dstImmutables.maker.get(),
            takerEthAddress: dstImmutables.taker.get(),
            makerCardanoAddress: makerCardanoAddress,
            takerCardanoAddress: takerCardanoAddress,
            amountEth: dstImmutables.amount,
            amountCardano: amountCardano,
            secretHash: dstImmutables.hashlock,
            createdAt: block.timestamp,
            status: 0 // Active
        });

        swaps[swapId] = swap;
        swapExists[swapId] = true;
        allSwapIds.push(swapId);

        emit CardanoSwapInitiated(
            swapId,
            SWAP_CARDANO_TO_ETH,
            dstImmutables.maker.get(),
            dstImmutables.taker.get(),
            makerCardanoAddress,
            takerCardanoAddress,
            dstImmutables.amount,
            amountCardano,
            dstImmutables.hashlock
        );
    }

    /**
     * @notice Complete swap by withdrawing from escrow with secret
     * @param swapId The swap identifier
     * @param escrow The escrow contract
     * @param secret The secret to unlock the escrow
     * @param immutables The immutables of the escrow contract
     */
    function completeSwap(
        bytes32 swapId,
        IEscrow escrow,
        bytes32 secret,
        IBaseEscrow.Immutables calldata immutables
    ) external {
        require(swapExists[swapId], "Swap not found");
        
        CrossChainSwap storage swap = swaps[swapId];
        require(swap.status == 0, "Swap not active");

        // Withdraw from escrow
        escrow.withdraw(secret, immutables);

        // Update swap status
        swap.status = 1; // Completed

        emit CardanoSwapCompleted(swapId, secret, msg.sender);
    }

    /**
     * @notice Cancel swap by cancelling the escrow
     * @param swapId The swap identifier
     * @param escrow The escrow contract
     * @param immutables The immutables of the escrow contract
     */
    function cancelSwap(
        bytes32 swapId,
        IEscrow escrow,
        IBaseEscrow.Immutables calldata immutables
    ) external {
        require(swapExists[swapId], "Swap not found");
        
        CrossChainSwap storage swap = swaps[swapId];
        require(swap.status == 0, "Swap not active");

        // Cancel escrow
        escrow.cancel(immutables);

        // Update swap status
        swap.status = 2; // Cancelled

        emit CardanoSwapCancelled(swapId, msg.sender);
    }

    /**
     * @notice Update Cardano escrow ID for ETH to Cardano swaps
     * @param swapId The swap identifier
     * @param cardanoEscrowId The Cardano escrow ID
     */
    function updateCardanoEscrowId(bytes32 swapId, string calldata cardanoEscrowId) external onlyOwner {
        require(swapExists[swapId], "Swap not found");
        
        CrossChainSwap storage swap = swaps[swapId];
        require(swap.direction == SWAP_ETH_TO_CARDANO, "Invalid swap direction");
        
        swap.cardanoEscrowId = cardanoEscrowId;
    }

    /**
     * @notice Regular deploySrc function for backward compatibility
     */
    function deploySrc(
        IBaseEscrow.Immutables calldata immutables,
        IOrderMixin.Order calldata order,
        bytes32 r,
        bytes32 vs,
        uint256 amount,
        TakerTraits takerTraits,
        bytes calldata args
    ) external payable onlyOwner {
        IBaseEscrow.Immutables memory immutablesMem = immutables;
        immutablesMem.timelocks = TimelocksLib.setDeployedAt(immutables.timelocks, block.timestamp);
        address computed = _FACTORY.addressOfEscrowSrc(immutablesMem);

        (bool success,) = address(computed).call{value: immutablesMem.safetyDeposit}("");
        if (!success) revert IBaseEscrow.NativeTokenSendingFailure();

        // _ARGS_HAS_TARGET = 1 << 251
        takerTraits = TakerTraits.wrap(TakerTraits.unwrap(takerTraits) | uint256(1 << 251));
        bytes memory argsMem = abi.encodePacked(computed, args);
        _LOP.fillOrderArgs(order, r, vs, amount, takerTraits, argsMem);
    }

    /**
     * @notice Regular deployDst function for backward compatibility
     */
    function deployDst(IBaseEscrow.Immutables calldata dstImmutables, uint256 srcCancellationTimestamp) external onlyOwner payable {
        _FACTORY.createDstEscrow{value: msg.value}(dstImmutables, srcCancellationTimestamp);
    }

    /**
     * @notice Regular withdraw function for backward compatibility
     */
    function withdraw(IEscrow escrow, bytes32 secret, IBaseEscrow.Immutables calldata immutables) external {
        escrow.withdraw(secret, immutables);
    }

    /**
     * @notice Regular cancel function for backward compatibility
     */
    function cancel(IEscrow escrow, IBaseEscrow.Immutables calldata immutables) external {
        escrow.cancel(immutables);
    }

    /**
     * @notice Arbitrary calls function for admin operations
     */
    function arbitraryCalls(address[] calldata targets, bytes[] calldata arguments) external onlyOwner {
        uint256 length = targets.length;
        if (targets.length != arguments.length) revert LengthMismatch();
        for (uint256 i = 0; i < length; ++i) {
            // solhint-disable-next-line avoid-low-level-calls
            (bool success,) = targets[i].call(arguments[i]);
            if (!success) RevertReasonForwarder.reRevert();
        }
    }

    /// @notice View functions
    function getSwap(bytes32 swapId) external view returns (CrossChainSwap memory) {
        require(swapExists[swapId], "Swap not found");
        return swaps[swapId];
    }

    function getAllSwapIds() external view returns (bytes32[] memory) {
        return allSwapIds;
    }

    function getSwapCount() external view returns (uint256) {
        return allSwapIds.length;
    }

    function isSwapActive(bytes32 swapId) external view returns (bool) {
        if (!swapExists[swapId]) return false;
        return swaps[swapId].status == 0;
    }
}