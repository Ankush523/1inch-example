/// Cross-chain escrow base module that provides core functionality for Ethereum-Aptos swaps
/// Preserves hashlock and timelock functionality from the EVM implementation
module bridge::base_escrow {
    use std::signer;
    use std::error;
    use std::vector;
    use std::option::{Self, Option};
    use aptos_framework::timestamp;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::event;
    use aptos_std::hash;

    /// Error codes
    const E_ESCROW_NOT_FOUND: u64 = 1;
    const E_INVALID_CALLER: u64 = 2;
    const E_INVALID_SECRET: u64 = 3;
    const E_INVALID_TIME: u64 = 4;
    const E_ESCROW_ALREADY_EXISTS: u64 = 5;
    const E_INSUFFICIENT_FUNDS: u64 = 6;
    const E_INVALID_HASHLOCK: u64 = 7;
    const E_ALREADY_WITHDRAWN: u64 = 8;
    const E_ALREADY_CANCELLED: u64 = 9;

    /// Timelock structure matching EVM implementation
    struct Timelocks has copy, drop, store {
        withdrawal_start: u64,
        withdrawal_end: u64,
        cancellation_start: u64,
        cancellation_end: u64,
    }

    /// Immutable escrow parameters
    struct EscrowImmutables has copy, drop, store {
        order_hash: vector<u8>,      // 32 bytes
        hashlock: vector<u8>,        // 32 bytes - hash of the secret
        maker: address,
        taker: address,
        token_type: u8,              // 0 = AptosCoin, 1 = Custom token
        amount: u64,
        safety_deposit: u64,
        timelocks: Timelocks,
        src_chain_id: u64,           // Source chain ID (Ethereum)
        dst_chain_id: u64,           // Destination chain ID (Aptos)
    }

    /// Escrow state
    struct EscrowData<phantom CoinType> has store {
        immutables: EscrowImmutables,
        locked_funds: Coin<CoinType>,
        safety_deposit: Coin<AptosCoin>,
        status: u8,                  // 0 = Active, 1 = Withdrawn, 2 = Cancelled
        secret: Option<vector<u8>>,  // Revealed secret after withdrawal
        created_at: u64,
    }

    /// Resource to store escrows for an account
    struct EscrowStore<phantom CoinType> has key {
        escrows: vector<EscrowData<CoinType>>,
        next_id: u64,
    }

    /// Events
    #[event]
    struct EscrowCreated has drop, store {
        escrow_id: u64,
        maker: address,
        taker: address,
        amount: u64,
        hashlock: vector<u8>,
        created_at: u64,
    }

    #[event]
    struct EscrowWithdrawn has drop, store {
        escrow_id: u64,
        taker: address,
        secret: vector<u8>,
        withdrawn_at: u64,
    }

    #[event]
    struct EscrowCancelled has drop, store {
        escrow_id: u64,
        maker: address,
        cancelled_at: u64,
    }

    #[event]
    struct FundsRescued has drop, store {
        escrow_id: u64,
        taker: address,
        amount: u64,
        rescued_at: u64,
    }

    /// Initialize escrow store for a user
    public fun initialize_escrow_store<CoinType>(account: &signer) {
        let account_addr = signer::address_of(account);
        if (!exists<EscrowStore<CoinType>>(account_addr)) {
            move_to(account, EscrowStore<CoinType> {
                escrows: vector::empty(),
                next_id: 0,
            });
        };
    }

    /// Create a new escrow (for destination chain - receiving from Ethereum)
    public fun create_dst_escrow<CoinType>(
        account: &signer,
        immutables: EscrowImmutables,
        locked_funds: Coin<CoinType>,
        safety_deposit: Coin<AptosCoin>,
    ): u64 acquires EscrowStore {
        let account_addr = signer::address_of(account);
        
        // Validate immutables
        assert!(vector::length(&immutables.hashlock) == 32, error::invalid_argument(E_INVALID_HASHLOCK));
        assert!(coin::value(&locked_funds) == immutables.amount, error::invalid_argument(E_INSUFFICIENT_FUNDS));
        
        // Initialize store if needed
        if (!exists<EscrowStore<CoinType>>(account_addr)) {
            initialize_escrow_store<CoinType>(account);
        };

        let store = borrow_global_mut<EscrowStore<CoinType>>(account_addr);
        let escrow_id = store.next_id;
        store.next_id = store.next_id + 1;

        let now = timestamp::now_seconds();
        let escrow = EscrowData<CoinType> {
            immutables,
            locked_funds,
            safety_deposit,
            status: 0, // Active
            secret: option::none(),
            created_at: now,
        };

        vector::push_back(&mut store.escrows, escrow);

        // Emit event
        event::emit(EscrowCreated {
            escrow_id,
            maker: immutables.maker,
            taker: immutables.taker,
            amount: immutables.amount,
            hashlock: immutables.hashlock,
            created_at: now,
        });

        escrow_id
    }

    /// Withdraw funds from escrow using secret
    public fun withdraw<CoinType>(
        account: &signer,
        escrow_id: u64,
        secret: vector<u8>,
    ): (Coin<CoinType>, Coin<AptosCoin>) acquires EscrowStore {
        let account_addr = signer::address_of(account);
        assert!(exists<EscrowStore<CoinType>>(account_addr), error::not_found(E_ESCROW_NOT_FOUND));

        let store = borrow_global_mut<EscrowStore<CoinType>>(account_addr);
        assert!(escrow_id < vector::length(&store.escrows), error::not_found(E_ESCROW_NOT_FOUND));

        let escrow = vector::borrow_mut(&mut store.escrows, escrow_id);
        
        // Validate caller is taker
        assert!(account_addr == escrow.immutables.taker, error::permission_denied(E_INVALID_CALLER));
        
        // Validate secret
        let secret_hash = hash::sha3_256(secret);
        assert!(secret_hash == escrow.immutables.hashlock, error::invalid_argument(E_INVALID_SECRET));
        
        // Validate time (withdrawal period)
        let now = timestamp::now_seconds();
        let withdrawal_start = escrow.created_at + escrow.immutables.timelocks.withdrawal_start;
        let withdrawal_end = escrow.created_at + escrow.immutables.timelocks.withdrawal_end;
        assert!(now >= withdrawal_start && now < withdrawal_end, error::invalid_state(E_INVALID_TIME));
        
        // Validate status
        assert!(escrow.status == 0, error::invalid_state(E_ALREADY_WITHDRAWN));

        // Update status and store secret
        escrow.status = 1; // Withdrawn
        escrow.secret = option::some(secret);

        // Extract funds
        let funds = coin::extract_all(&mut escrow.locked_funds);
        let safety_deposit = coin::extract_all(&mut escrow.safety_deposit);

        // Emit event
        event::emit(EscrowWithdrawn {
            escrow_id,
            taker: account_addr,
            secret,
            withdrawn_at: now,
        });

        (funds, safety_deposit)
    }

    /// Cancel escrow and return funds to maker
    public fun cancel<CoinType>(
        account: &signer,
        escrow_id: u64,
    ): (Coin<CoinType>, Coin<AptosCoin>) acquires EscrowStore {
        let account_addr = signer::address_of(account);
        assert!(exists<EscrowStore<CoinType>>(account_addr), error::not_found(E_ESCROW_NOT_FOUND));

        let store = borrow_global_mut<EscrowStore<CoinType>>(account_addr);
        assert!(escrow_id < vector::length(&store.escrows), error::not_found(E_ESCROW_NOT_FOUND));

        let escrow = vector::borrow_mut(&mut store.escrows, escrow_id);
        
        // Validate caller is maker
        assert!(account_addr == escrow.immutables.maker, error::permission_denied(E_INVALID_CALLER));
        
        // Validate time (cancellation period)
        let now = timestamp::now_seconds();
        let cancellation_start = escrow.created_at + escrow.immutables.timelocks.cancellation_start;
        assert!(now >= cancellation_start, error::invalid_state(E_INVALID_TIME));
        
        // Validate status
        assert!(escrow.status == 0, error::invalid_state(E_ALREADY_CANCELLED));

        // Update status
        escrow.status = 2; // Cancelled

        // Extract funds
        let funds = coin::extract_all(&mut escrow.locked_funds);
        let safety_deposit = coin::extract_all(&mut escrow.safety_deposit);

        // Emit event
        event::emit(EscrowCancelled {
            escrow_id,
            maker: account_addr,
            cancelled_at: now,
        });

        (funds, safety_deposit)
    }

    /// Rescue funds after rescue delay (emergency function)
    public fun rescue_funds<CoinType>(
        account: &signer,
        escrow_id: u64,
        rescue_delay: u64,
    ): (Coin<CoinType>, Coin<AptosCoin>) acquires EscrowStore {
        let account_addr = signer::address_of(account);
        assert!(exists<EscrowStore<CoinType>>(account_addr), error::not_found(E_ESCROW_NOT_FOUND));

        let store = borrow_global_mut<EscrowStore<CoinType>>(account_addr);
        assert!(escrow_id < vector::length(&store.escrows), error::not_found(E_ESCROW_NOT_FOUND));

        let escrow = vector::borrow_mut(&mut store.escrows, escrow_id);
        
        // Validate caller is taker
        assert!(account_addr == escrow.immutables.taker, error::permission_denied(E_INVALID_CALLER));
        
        // Validate rescue time
        let now = timestamp::now_seconds();
        let rescue_start = escrow.created_at + rescue_delay;
        assert!(now >= rescue_start, error::invalid_state(E_INVALID_TIME));

        // Extract all remaining funds
        let funds = coin::extract_all(&mut escrow.locked_funds);
        let safety_deposit = coin::extract_all(&mut escrow.safety_deposit);

        // Emit event
        event::emit(FundsRescued {
            escrow_id,
            taker: account_addr,
            amount: coin::value(&funds),
            rescued_at: now,
        });

        (funds, safety_deposit)
    }

    /// View functions
    public fun get_escrow_data<CoinType>(
        account: address,
        escrow_id: u64,
    ): (EscrowImmutables, u8, Option<vector<u8>>, u64) acquires EscrowStore {
        assert!(exists<EscrowStore<CoinType>>(account), error::not_found(E_ESCROW_NOT_FOUND));
        
        let store = borrow_global<EscrowStore<CoinType>>(account);
        assert!(escrow_id < vector::length(&store.escrows), error::not_found(E_ESCROW_NOT_FOUND));
        
        let escrow = vector::borrow(&store.escrows, escrow_id);
        (escrow.immutables, escrow.status, escrow.secret, escrow.created_at)
    }

    public fun get_escrow_count<CoinType>(account: address): u64 acquires EscrowStore {
        if (!exists<EscrowStore<CoinType>>(account)) {
            return 0
        };
        let store = borrow_global<EscrowStore<CoinType>>(account);
        vector::length(&store.escrows)
    }

    /// Helper functions
    public fun create_timelocks(
        withdrawal_start: u64,
        withdrawal_end: u64,
        cancellation_start: u64,
        cancellation_end: u64,
    ): Timelocks {
        Timelocks {
            withdrawal_start,
            withdrawal_end,
            cancellation_start,
            cancellation_end,
        }
    }

    public fun create_immutables(
        order_hash: vector<u8>,
        hashlock: vector<u8>,
        maker: address,
        taker: address,
        token_type: u8,
        amount: u64,
        safety_deposit: u64,
        timelocks: Timelocks,
        src_chain_id: u64,
        dst_chain_id: u64,
    ): EscrowImmutables {
        EscrowImmutables {
            order_hash,
            hashlock,
            maker,
            taker,
            token_type,
            amount,
            safety_deposit,
            timelocks,
            src_chain_id,
            dst_chain_id,
        }
    }
}
