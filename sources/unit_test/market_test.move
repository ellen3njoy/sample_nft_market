#[test_only]
module market::market_test {
    use market::market;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;
    use aptos_framework::aptos_coin;
    use aptos_framework::coin::Coin;
    use std::signer::address_of;
    use aptos_framework::account;
    use std::signer;
    use aptos_token::token;
    use std::string::String;

    struct AptosCoinCap has key {
        mint_cap: coin::MintCapability<AptosCoin>,
        burn_cap: coin::BurnCapability<AptosCoin>
    }

    public fun init(sender: &signer, framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        coin::register<AptosCoin>(sender);
        let (burn_cap, mint_cap) = aptos_coin::initialize_for_test(framework);
        move_to(sender, AptosCoinCap {
            mint_cap,
            burn_cap
        });
    }

    public fun mint_apt(sender: &signer, amount: u64): Coin<AptosCoin> acquires AptosCoinCap {
        let cap = &borrow_global<AptosCoinCap>(address_of(sender)).mint_cap;
        coin::mint(amount, cap)
    }



    #[test(aptos_framework = @0x1,market = @market,sender = @0x1234)]
    fun test_list(aptos_framework:&signer,market: &signer,sender: &signer) acquires AptosCoinCap {
        account::create_account_for_test(signer::address_of(market));
        account::create_account_for_test(signer::address_of(sender));
        account::create_account_for_test(signer::address_of(aptos_framework));

        init(market, aptos_framework);
        coin::deposit(address_of(market), mint_apt(market, 10 * 1000 * 1000 * 1000 * 1000));
        let token_id = token::create_collection_and_token(
            market,
            1,
            5,
            1,
            vector<String>[],
            vector<vector<u8>>[],
            vector<String>[],
            vector<bool>[false, false, false],
            vector<bool>[false, false, false, false, false],
        );

        let (creator_address, collection, name, version) = token::get_token_id_fields(
            &token_id
        );

        market::list<AptosCoin>(
            market,
            creator_address,
            collection,
            name,
            version,
            1,
            10000 * 10000
        );

    }

    #[test(aptos_framework = @0x1,market = @market,sender = @0x1234)]
    fun test_buy(aptos_framework:&signer,market: &signer,sender: &signer) acquires AptosCoinCap {
        account::create_account_for_test(signer::address_of(market));
        account::create_account_for_test(signer::address_of(sender));
        account::create_account_for_test(signer::address_of(aptos_framework));

        init(market, aptos_framework);
        coin::register<AptosCoin>(sender);
        coin::deposit(address_of(sender), mint_apt(market, 10 * 1000 * 1000 * 1000 * 1000));
        let token_id = token::create_collection_and_token(
            market,
            1,
            5,
            1,
            vector<String>[],
            vector<vector<u8>>[],
            vector<String>[],
            vector<bool>[false, false, false],
            vector<bool>[false, false, false, false, false],
        );

        let (creator_address, collection, name, version) = token::get_token_id_fields(
            &token_id
        );

        market::list<AptosCoin>(
            market,
            creator_address,
            collection,
            name,
            version,
            1,
            10000 * 10000
        );

        market::buy<AptosCoin>(
            sender,
            10000 * 10000,
            signer::address_of(market),
            creator_address,
            collection,
            name,
            version,
            1,
        );
        assert!(coin::balance<AptosCoin>(@market) == 10000 * 10000, 100);
    }

    #[test(aptos_framework = @0x1,market = @market,sender = @0x1234)]
    fun test_cancel(aptos_framework:&signer,market: &signer,sender: &signer) acquires AptosCoinCap {
        account::create_account_for_test(signer::address_of(market));
        account::create_account_for_test(signer::address_of(sender));
        account::create_account_for_test(signer::address_of(aptos_framework));

        init(market, aptos_framework);
        coin::register<AptosCoin>(sender);
        coin::deposit(address_of(sender), mint_apt(market, 10 * 1000 * 1000 * 1000 * 1000));
        let token_id = token::create_collection_and_token(
            market,
            1,
            5,
            1,
            vector<String>[],
            vector<vector<u8>>[],
            vector<String>[],
            vector<bool>[false, false, false],
            vector<bool>[false, false, false, false, false],
        );

        let (creator_address, collection, name, version) = token::get_token_id_fields(
            &token_id
        );

        market::list<AptosCoin>(
            market,
            creator_address,
            collection,
            name,
            version,
            1,
            10000 * 10000
        );

        market::cancel<AptosCoin>(
            market,
            creator_address,
            collection,
            name,
            version,
            1,
        );
        assert!(token::balance_of(@market,token_id) == 1, 100);
    }

}
