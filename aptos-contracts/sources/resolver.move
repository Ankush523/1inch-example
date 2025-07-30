/// Cross-chain swap resolver for Aptos side
/// Manages the lifecycle of cross-chain swaps between Ethereum and Aptos
module bridge::resolver {
    use std::signer;
    use std::error;
    use std::vector;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;
    use aptos_framework::event;
    use bridge::base_escrow::{Self, Timelocks};

    /// Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_INSUFFICIENT_FUNDS: u64 = 2;
    const E_INVALID_SWAP_DATA: u64 = 3;
    const E_SWAP_ALREADY_EXISTS: u64 = 4;
    const E_SWAP_NOT_FOUND: u64 = 5;

    /// Swap direction
    const SWAP_ETH_TO_APTOS: u8 = 0;
    const SWAP_APTOS_TO_ETH: u8 = 1;

    /// Swap metadata for cross-chain coordination
    struct SwapMetadata has copy, drop, store {
        swap_id: vector<u8>,         // Unique swap identifier
        direction: u8,               // 0 = ETH->Aptos, 1 = Aptos->ETH
        eth_order_hash: vector<u8>,  // Ethereum order hash
        eth_escrow_address: vector<u8>, // Ethereum escrow contract address
        aptos_escrow_id: u64,        // Aptos escrow ID
        maker_eth_address: vector<u8>, // Ethereum maker address
        taker_eth_address: vector<u8>, // Ethereum taker address
        maker_aptos_address: address,  // Aptos maker address
        taker_aptos_address: address,  // Aptos taker address
        amount_eth: u64,             // Amount on Ethereum side
        amount_aptos: u64,           // Amount on Aptos side
        secret_hash: vector<u8>,     // Hash of the secret
        created_at: u64,
        status: u8,                  // 0 = Active, 1 = Completed, 2 = Cancelled
    }

    /// Resource to store swap data
    struct SwapRegistry has key {
        swaps: vector<SwapMetadata>,
        next_swap_id: u64,
    }

    /// Events
    #[event]
    struct SwapInitiated has drop, store {
        swap_id: vector<u8>,
        direction: u8,
        maker_aptos: address,
        taker_aptos: address,
        amount: u64,
        secret_hash: vector<u8>,
        created_at: u64,
    }

    #[event]
    struct SwapCompleted has drop, store {
        swap_id: vector<u8>,
        secret: vector<u8>,
        completed_at: u64,
    }

    #[event]
    struct SwapCancelled has drop, store {
        swap_id: vector<u8>,
        cancelled_at: u64,
    }

    /// Initialize the swap registry
    fun init_module(account: &signer) {
        move_to(account, SwapRegistry {
            swaps: vector::empty(),
            next_swap_id: 0,
        });
    }

    /// Initialize swap registry for an account (if not module deployer)
    public fun initialize_swap_registry(account: &signer) {
        let account_addr = signer::address_of(account);
        if (!exists<SwapRegistry>(account_addr)) {
            move_to(account, SwapRegistry {
                swaps: vector::empty(),
                next_swap_id: 0,
            });
        };
    }

    /// Initiate ETH to Aptos swap (called when ETH escrow is created)
    public fun initiate_eth_to_aptos_swap<CoinType>(
        resolver: &signer,
        swap_id: vector<u8>,
        eth_order_hash: vector<u8>,
        eth_escrow_address: vector<u8>,
        maker_eth_address: vector<u8>,
        taker_eth_address: vector<u8>,
        maker_aptos_address: address,
        taker_aptos_address: address,
        amount_eth: u64,
        amount_aptos: u64,
        secret_hash: vector<u8>,
        locked_funds: Coin<CoinType>,
        safety_deposit: Coin<AptosCoin>,
        timelocks: Timelocks,
    ): u64 acquires SwapRegistry {
        let resolver_addr = signer::address_of(resolver);
        
        // Initialize registry if needed
        if (!exists<SwapRegistry>(resolver_addr)) {
            initialize_swap_registry(resolver);
        };

        // Create escrow immutables
        let immutables = base_escrow::create_immutables(
            eth_order_hash,
            secret_hash,
            maker_aptos_address,
            taker_aptos_address,
            0, // AptosCoin type
            amount_aptos,
            coin::value(&safety_deposit),
            timelocks,
            1, // Ethereum chain ID
            1, // Aptos chain ID (placeholder)
        );

        // Create escrow
        base_escrow::initialize_escrow_store<CoinType>(resolver);
        let escrow_id = base_escrow::create_dst_escrow<CoinType>(
            resolver,
            immutables,
            locked_funds,
            safety_deposit,
        );

        // Record swap metadata
        let registry = borrow_global_mut<SwapRegistry>(resolver_addr);
        let swap_metadata = SwapMetadata {
            swap_id,
            direction: SWAP_ETH_TO_APTOS,
            eth_order_hash,
            eth_escrow_address,
            aptos_escrow_id: escrow_id,
            maker_eth_address,
            taker_eth_address,
            maker_aptos_address,
            taker_aptos_address,
            amount_eth,
            amount_aptos,
            secret_hash,
            created_at: timestamp::now_seconds(),
            status: 0, // Active
        };

        vector::push_back(&mut registry.swaps, swap_metadata);

        // Emit event
        event::emit(SwapInitiated {
            swap_id,
            direction: SWAP_ETH_TO_APTOS,
            maker_aptos: maker_aptos_address,
            taker_aptos: taker_aptos_address,
            amount: amount_aptos,
            secret_hash,
            created_at: timestamp::now_seconds(),
        });

        escrow_id
    }

    /// Initiate Aptos to ETH swap (called to create Aptos escrow)
    public fun initiate_aptos_to_eth_swap<CoinType>(
        maker: &signer,
        swap_id: vector<u8>,
        taker_aptos_address: address,
        maker_eth_address: vector<u8>,
        taker_eth_address: vector<u8>,
        amount_eth: u64,
        amount_aptos: u64,
        secret_hash: vector<u8>,
        locked_funds: Coin<CoinType>,
        safety_deposit: Coin<AptosCoin>,
        timelocks: Timelocks,
    ): u64 acquires SwapRegistry {
        let maker_addr = signer::address_of(maker);
        
        // Initialize registry if needed
        if (!exists<SwapRegistry>(maker_addr)) {
            initialize_swap_registry(maker);
        };

        // Create escrow immutables
        let immutables = base_escrow::create_immutables(
            vector::empty<u8>(), // No ETH order hash yet
            secret_hash,
            maker_addr,
            taker_aptos_address,
            0, // AptosCoin type
            amount_aptos,
            coin::value(&safety_deposit),
            timelocks,
            1, // Ethereum chain ID
            1, // Aptos chain ID (placeholder)
        );

        // Create escrow
        base_escrow::initialize_escrow_store<CoinType>(maker);
        let escrow_id = base_escrow::create_dst_escrow<CoinType>(
            maker,
            immutables,
            locked_funds,
            safety_deposit,
        );

        // Record swap metadata
        let registry = borrow_global_mut<SwapRegistry>(maker_addr);
        let swap_metadata = SwapMetadata {
            swap_id,
            direction: SWAP_APTOS_TO_ETH,
            eth_order_hash: vector::empty<u8>(),
            eth_escrow_address: vector::empty<u8>(),
            aptos_escrow_id: escrow_id,
            maker_eth_address,
            taker_eth_address,
            maker_aptos_address: maker_addr,
            taker_aptos_address,
            amount_eth,
            amount_aptos,
            secret_hash,
            created_at: timestamp::now_seconds(),
            status: 0, // Active
        };

        vector::push_back(&mut registry.swaps, swap_metadata);

        // Emit event
        event::emit(SwapInitiated {
            swap_id,
            direction: SWAP_APTOS_TO_ETH,
            maker_aptos: maker_addr,
            taker_aptos: taker_aptos_address,
            amount: amount_aptos,
            secret_hash,
            created_at: timestamp::now_seconds(),
        });

        escrow_id
    }

    /// Complete swap by revealing secret (withdraw funds)
    public fun complete_swap<CoinType>(
        account: &signer,
        swap_index: u64,
        secret: vector<u8>,
    ): (Coin<CoinType>, Coin<AptosCoin>) acquires SwapRegistry {
        let account_addr = signer::address_of(account);
        assert!(exists<SwapRegistry>(account_addr), error::not_found(E_SWAP_NOT_FOUND));

        let registry = borrow_global_mut<SwapRegistry>(account_addr);
        assert!(swap_index < vector::length(&registry.swaps), error::not_found(E_SWAP_NOT_FOUND));

        let swap = vector::borrow_mut(&mut registry.swaps, swap_index);
        let escrow_id = swap.aptos_escrow_id;
        let swap_id = swap.swap_id;

        // Update swap status
        swap.status = 1; // Completed

        // Withdraw from escrow
        let (funds, safety_deposit) = base_escrow::withdraw<CoinType>(account, escrow_id, secret);

        // Emit event
        event::emit(SwapCompleted {
            swap_id,
            secret,
            completed_at: timestamp::now_seconds(),
        });

        (funds, safety_deposit)
    }

    /// Cancel swap (return funds to maker)
    public fun cancel_swap<CoinType>(
        account: &signer,
        swap_index: u64,
    ): (Coin<CoinType>, Coin<AptosCoin>) acquires SwapRegistry {
        let account_addr = signer::address_of(account);
        assert!(exists<SwapRegistry>(account_addr), error::not_found(E_SWAP_NOT_FOUND));

        let registry = borrow_global_mut<SwapRegistry>(account_addr);
        assert!(swap_index < vector::length(&registry.swaps), error::not_found(E_SWAP_NOT_FOUND));

        let swap = vector::borrow_mut(&mut registry.swaps, swap_index);
        let escrow_id = swap.aptos_escrow_id;
        let swap_id = swap.swap_id;

        // Update swap status
        swap.status = 2; // Cancelled

        // Cancel escrow
        let (funds, safety_deposit) = base_escrow::cancel<CoinType>(account, escrow_id);

        // Emit event
        event::emit(SwapCancelled {
            swap_id,
            cancelled_at: timestamp::now_seconds(),
        });

        (funds, safety_deposit)
    }

    /// View functions
    public fun get_swap_metadata(
        account: address,
        swap_index: u64,
    ): SwapMetadata acquires SwapRegistry {
        assert!(exists<SwapRegistry>(account), error::not_found(E_SWAP_NOT_FOUND));
        
        let registry = borrow_global<SwapRegistry>(account);
        assert!(swap_index < vector::length(&registry.swaps), error::not_found(E_SWAP_NOT_FOUND));
        
        *vector::borrow(&registry.swaps, swap_index)
    }

    public fun get_swap_count(account: address): u64 acquires SwapRegistry {
        if (!exists<SwapRegistry>(account)) {
            return 0
        };
        let registry = borrow_global<SwapRegistry>(account);
        vector::length(&registry.swaps)
    }

    public fun find_swap_by_id(
        account: address,
        swap_id: vector<u8>,
    ): (bool, u64) acquires SwapRegistry {
        if (!exists<SwapRegistry>(account)) {
            return (false, 0)
        };
        
        let registry = borrow_global<SwapRegistry>(account);
        let len = vector::length(&registry.swaps);
        let i = 0;
        
        while (i < len) {
            let swap = vector::borrow(&registry.swaps, i);
            if (swap.swap_id == swap_id) {
                return (true, i)
            };
            i = i + 1;
        };
        
        (false, 0)
    }
}
