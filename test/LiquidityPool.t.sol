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

    function test_RevertWhen_ZeroDeposit() public {
        vm.prank(user1);
        vm.expectRevert("Invalid deposit");
        pool.deposit{value: 0}();
    }

    function test_RevertWhen_ZeroDepositFor() public {
        vm.prank(user1);
        vm.expectRevert("Invalid deposit");
        pool.depositFor{value: 0}(user2);
    }

    function test_RevertWhen_WithdrawMoreThanDeposited() public {
        // Setup: deposit
        vm.startPrank(user1);
        pool.deposit{value: 1 ether}();

        // Approve pool token transfer
        pool.poolToken().approve(address(pool), 2 ether);

        // Wait for withdrawal delay
        skip(pool.WITHDRAWAL_DELAY());

        // Try to withdraw more than deposited
        vm.expectRevert("Insufficient deposit");
        pool.withdraw(2 ether);
        vm.stopPrank();
    }

    function test_RevertWhen_WithdrawBeforeDelay() public {
        // Setup: deposit
        vm.startPrank(user1);
        pool.deposit{value: 1 ether}();

        // Approve pool token transfer
        pool.poolToken().approve(address(pool), 1 ether);

        // Try to withdraw before delay period
        vm.expectRevert("Withdrawal delay not met");
        pool.withdraw(1 ether);
        vm.stopPrank();
    }

    function test_RevertWhen_ClaimRewardWithInvalidSignature() public {
        // Setup
        vm.prank(user1);
        pool.deposit{value: 1 ether}();

        uint256 nonce = pool.nonces(user1);
        bytes32 messageHash = keccak256(abi.encode(user1, 0.1 ether, nonce));
        bytes32 invalidHash = keccak256(abi.encode(user2, 0.1 ether, nonce)); // Different user
        bytes memory invalidSignature = abi.encode(invalidHash);

        vm.prank(user1);
        vm.expectRevert("Invalid signature");
        pool.claimReward(0.1 ether, nonce, invalidSignature);
    }

    function test_RevertWhen_ClaimRewardWithInvalidNonce() public {
        // Setup
        vm.prank(user1);
        pool.deposit{value: 1 ether}();

        uint256 nonce = pool.nonces(user1);
        uint256 invalidNonce = nonce + 1;
        bytes32 messageHash = keccak256(abi.encode(user1, 0.1 ether, invalidNonce));
        bytes memory signature = abi.encode(messageHash);

        vm.prank(user1);
        vm.expectRevert("Invalid nonce");
        pool.claimReward(0.1 ether, invalidNonce, signature);
    }

    function test_RevertWhen_ClaimRewardWithInsufficientRewards() public {
        // Setup
        vm.prank(user1);
        pool.deposit{value: 1 ether}();

        uint256 nonce = pool.nonces(user1);
        uint256 excessiveAmount = (1 ether * pool.REWARD_RATE()) / 100 + 1 ether; // More than available
        bytes32 messageHash = keccak256(abi.encode(user1, excessiveAmount, nonce));
        bytes memory signature = abi.encode(messageHash);

        vm.prank(user1);
        vm.expectRevert("Insufficient rewards");
        pool.claimReward(excessiveAmount, nonce, signature);
    }

    function test_RevertWhen_SetInvalidLendingMarket() public {
        vm.expectRevert("Invalid address");
        pool.setLendingMarket(address(0));
    }

    function test_RevertWhen_SetInvalidStableCoin() public {
        vm.expectRevert("Invalid address");
        pool.setStableCoin(address(0));
    }

    function testCreateExistingMarket() public {
        // Create market first time
        vm.startPrank(user1);
        LiquidityPool.MarketInfo memory info1 = pool.createMarket(1000);

        // Create market second time with different price
        LiquidityPool.MarketInfo memory info2 = pool.createMarket(2000);
        vm.stopPrank();

        // Should return the original market info, not create a new one
        assertEq(info2.price, info1.price);
        assertEq(info2.creator, user1);
        assertTrue(info2.active);
    }

    receive() external payable {}
}
