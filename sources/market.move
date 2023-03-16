module market::market {
    use aptos_token::token::{TokenId, Token};
    use aptos_std::table::Table;
    use std::string::String;
    use aptos_token::token;
    use std::signer;
    use aptos_std::table;
    use std::error;
    use aptos_framework::coin;

    const ETOKEN_ALREADY_LISTED: u64 = 1;

    const ETOKEN_LISTING_NOT_EXIST: u64 = 2;

    const ETOKEN_NOT_IN_ESCROW: u64 = 3;

    const ETOKEN_CANNOT_MOVE_OUT_OF_ESCROW_BEFORE_LOCKUP_TIME: u64 = 4;

    const ETOKEN_MIN_PRICE_NOT_MATCH: u64 = 5;

    const ETOKEN_AMOUNT_NOT_MATCH: u64 = 6;

    const ENOT_ENOUGH_COIN: u64 = 7;

    const EROYALTY_ERROR: u64 = 8;

    const EUNAVAILABLE: u64 = 64;

    struct TokenStoreEscrow has key {
        token_escrows: Table<TokenId, Token>,
    }

    struct TokenCoinSwap<phantom CoinType> has store, drop {
        token_amount: u64,
        min_price_per_token: u64,
    }

    struct TokenListings<phantom CoinType> has key {
        listings: Table<TokenId, TokenCoinSwap<CoinType>>,
    }

    public entry fun list<CoinType>(
        sender: &signer,
        creators_address: address,
        collection: String,
        name: String,
        property_version: u64,
        token_amount: u64,
        min_coin_per_token: u64,
    ) acquires TokenStoreEscrow, TokenListings {
        let sender_addr = signer::address_of(sender);
        let token_id = token::create_token_id_raw(creators_address, collection, name, property_version);
        let token = token::withdraw_token(sender, token_id, token_amount);
        if (!exists<TokenStoreEscrow>(sender_addr)) {
            let token_store_escrow = TokenStoreEscrow {
                token_escrows: table::new()
            };
            move_to(sender, token_store_escrow);
        };

        let tokens_in_escrow = &mut borrow_global_mut<TokenStoreEscrow>(sender_addr).token_escrows;
        if (table::contains(tokens_in_escrow, token_id)) {
            let dst = table::borrow_mut(tokens_in_escrow, token_id);
            token::merge(dst, token);
        } else {
            table::add(tokens_in_escrow, token_id, token);
        };


        if (!exists<TokenListings<CoinType>>(sender_addr)) {
            let token_listing = TokenListings<CoinType> {
                listings: table::new<TokenId, TokenCoinSwap<CoinType>>(),
            };
            move_to(sender, token_listing);
        };

        let swap = TokenCoinSwap<CoinType> {
            token_amount,
            min_price_per_token: min_coin_per_token
        };
        let listing = &mut borrow_global_mut<TokenListings<CoinType>>(sender_addr).listings;

        table::add(listing, token_id, swap);
    }

    public entry fun cancel<CoinType>(
        sender: &signer,
        creators_address: address,
        collection: String,
        name: String,
        property_version: u64,
        token_amount: u64
    ) acquires TokenListings, TokenStoreEscrow {
        let sender_addr = signer::address_of(sender);
        let listing = &mut borrow_global_mut<TokenListings<CoinType>>(sender_addr).listings;
        let token_id = token::create_token_id_raw(creators_address, collection, name, property_version);
        assert!(table::contains(listing, token_id), error::not_found(ETOKEN_LISTING_NOT_EXIST));
        table::remove(listing, token_id);
        let tokens_in_escrow = &mut borrow_global_mut<TokenStoreEscrow>(sender_addr).token_escrows;
        assert!(table::contains(tokens_in_escrow, token_id), error::not_found(ETOKEN_NOT_IN_ESCROW));
        let token_mut_ref = table::borrow_mut(tokens_in_escrow, token_id);

        let token = if (token_amount == token::get_token_amount(token_mut_ref)) {
            table::remove(tokens_in_escrow, token_id)
        } else {
            token::split(token_mut_ref, token_amount)
        };
        token::deposit_token(sender, token);
    }

    public entry fun buy<CoinType>(
        sender: &signer,
        coin_amount: u64,
        token_owner: address,
        creators_address: address,
        collection: String,
        name: String,
        property_version: u64,
        token_amount: u64
    ) acquires TokenListings, TokenStoreEscrow {
        let token_id = token::create_token_id_raw(creators_address, collection, name, property_version);
        let sender_addr = signer::address_of(sender);
        let token_listing = borrow_global_mut<TokenListings<CoinType>>(token_owner);
        assert!(table::contains(&token_listing.listings, token_id), error::not_found(ETOKEN_LISTING_NOT_EXIST));
        assert!(coin::balance<CoinType>(sender_addr) >= coin_amount, error::invalid_argument(ENOT_ENOUGH_COIN));
        let token_swap = table::borrow_mut(&mut token_listing.listings, token_id);
        assert!(
            token_swap.min_price_per_token * token_amount <= coin_amount,
            error::invalid_argument(ETOKEN_MIN_PRICE_NOT_MATCH)
        );
        assert!(token_swap.token_amount >= token_amount, error::invalid_argument(ETOKEN_AMOUNT_NOT_MATCH));

        // withdraw from token escrow of tokens
        let tokens_in_escrow = &mut borrow_global_mut<TokenStoreEscrow>(token_owner).token_escrows;
        assert!(table::contains(tokens_in_escrow, token_id), error::not_found(ETOKEN_NOT_IN_ESCROW));
        let token_mut_ref = table::borrow_mut(tokens_in_escrow, token_id);
        let token = if (token_amount == token::get_token_amount(token_mut_ref)) {
            table::remove(tokens_in_escrow, token_id)
        } else {
            token::split(token_mut_ref, token_amount)
        };

        token::deposit_token(sender, token);

        let total_cost = token_swap.min_price_per_token * token_amount;
        let coin = coin::withdraw<CoinType>(sender, total_cost);
        coin::deposit(token_owner, coin);

        if (token_swap.token_amount == token_amount) {
            table::remove(&mut token_listing.listings, token_id);
        } else {
            token_swap.token_amount = token_swap.token_amount - token_amount;
        };
    }
}
