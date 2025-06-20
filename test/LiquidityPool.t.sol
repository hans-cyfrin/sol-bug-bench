// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/LiquidityPool.sol";
import "../src/StableCoin.sol";

contract LiquidityPoolTest is Test {
    LiquidityPool public pool;
    StableCoin public stablecoin;
    address public owner;
    address public user1;
    address public user2;
    address public mockLendingMarket;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        mockLendingMarket = makeAddr("lendingMarket");

        // Deploy contracts
        pool = new LiquidityPool();
        stablecoin = new StableCoin();

        // Fund users
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function testInitialState() public {
        assertEq(pool.owner(), owner);
        assertEq(address(pool.poolToken()).code.length > 0, true);
        assertEq(pool.WITHDRAWAL_DELAY(), 1 days);
        assertEq(pool.REWARD_RATE(), 10);
    }

    function testSetLendingMarket() public {
        pool.setLendingMarket(mockLendingMarket);
        assertEq(pool.lendingMarket(), mockLendingMarket);
    }

    function testSetStableCoin() public {
        pool.setStableCoin(address(stablecoin));
        assertEq(address(pool.stablecoin()), address(stablecoin));
    }

    function testCreateMarket() public {
        vm.prank(user1);
        LiquidityPool.MarketInfo memory info = pool.createMarket(1000);

        assertEq(info.creator, user1);
        assertEq(info.price, 1000);
        assertTrue(info.active);
    }

    function testDeposit() public {
        uint256 depositAmount = 1 ether;

        vm.prank(user1);
        pool.deposit{value: depositAmount}();

        assertEq(pool.deposits(user1), depositAmount);
        assertEq(pool.totalDeposited(), depositAmount);
        assertEq(pool.poolToken().balanceOf(user1), depositAmount);
        assertEq(pool.rewards(user1), (depositAmount * pool.REWARD_RATE()) / 100);
    }

    function testDepositFor() public {
        uint256 depositAmount = 1 ether;

        vm.prank(user2);
        pool.depositFor{value: depositAmount}(user1);

        assertEq(pool.deposits(user1), depositAmount);
        assertEq(pool.totalDeposited(), depositAmount);
        assertEq(pool.poolToken().balanceOf(user1), depositAmount);
        assertEq(pool.rewards(user1), (depositAmount * pool.REWARD_RATE()) / 100);
    }

    function testWithdrawalRequest() public {
        // First deposit
        vm.prank(user1);
        pool.deposit{value: 1 ether}();

        // Request withdrawal
        vm.prank(user1);
        pool.requestWithdrawal(0.5 ether);

        // Check withdrawal queue
        (address payable user, uint256 amount) = pool.withdrawalQueue(0);
        assertEq(user, user1);
        assertEq(amount, 0.5 ether);
    }

    function testProcessWithdrawals() public {
        // Setup: deposit and request withdrawal
        vm.prank(user1);
        pool.deposit{value: 1 ether}();

        vm.prank(user1);
        pool.requestWithdrawal(0.5 ether);

        uint256 balanceBefore = user1.balance;

        // Process withdrawals
        pool.processWithdrawals(1);

        assertEq(user1.balance - balanceBefore, 0.5 ether);
    }

    function testWithdraw() public {
        // Setup: deposit
        vm.startPrank(user1);
        pool.deposit{value: 1 ether}();

        // Approve pool token transfer
        pool.poolToken().approve(address(pool), 1 ether);

        // Wait for withdrawal delay
        skip(pool.WITHDRAWAL_DELAY());

        // Withdraw
        pool.withdraw(0.5 ether);
        vm.stopPrank();

        assertEq(pool.deposits(user1), 0.5 ether);
        assertEq(pool.totalDeposited(), 0.5 ether);
    }

    function testClaimReward() public {
        // Setup
        vm.prank(user1);
        pool.deposit{value: 1 ether}();

        uint256 nonce = pool.nonces(user1);
        bytes32 messageHash = keccak256(abi.encode(user1, 0.1 ether, nonce));
        bytes memory signature = abi.encode(messageHash);

        vm.prank(user1);
        pool.claimReward(0.1 ether, nonce, signature);

        assertEq(pool.rewards(user1), (1 ether * pool.REWARD_RATE()) / 100 - 0.1 ether);
    }

    function testGetBalance() public {
        vm.deal(address(pool), 1 ether);
        assertEq(pool.getBalance(), 1 ether);
    }

    function testGetShares() public {
        vm.prank(user1);
        pool.deposit{value: 1 ether}();

        assertEq(pool.getShares(user1), 1 ether);
    }

    receive() external payable {}
}
