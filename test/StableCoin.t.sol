// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/StableCoin.sol";

contract StableCoinTest is Test {
    StableCoin public stablecoin;
    TokenStreamer public streamer;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy contracts
        stablecoin = new StableCoin();
        streamer = new TokenStreamer(stablecoin, 30 days);

        // Mint more tokens for testing
        stablecoin.mint(owner, 50000000 * 10 ** stablecoin.decimals());

        // Transfer some tokens to users for testing
        stablecoin.transfer(user1, 10000000 * 10 ** stablecoin.decimals()); // Much larger amount
        stablecoin.transfer(user2, 10000000 * 10 ** stablecoin.decimals()); // Much larger amount
    }

    function testInitialSupply() public {
        // Note: Initial supply + minted amount
        assertEq(stablecoin.totalSupply(), (1000000 + 50000000) * 10 ** stablecoin.decimals());
        assertEq(stablecoin.balanceOf(owner), (1000000 + 50000000 - 20000000) * 10 ** stablecoin.decimals());
    }

    function testDecimals() public {
        assertEq(stablecoin.decimals(), 1);
    }

    function testMint() public {
        uint256 mintAmount = 1000 * 10 ** stablecoin.decimals();
        stablecoin.mint(user1, mintAmount);
        assertEq(stablecoin.balanceOf(user1), (10000000 + 1000) * 10 ** stablecoin.decimals());
    }

    function testTokenStreamerDeposit() public {
        uint256 depositAmount = 100 * 10 ** stablecoin.decimals();

        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        streamer.depositToStream(user1, depositAmount);
        vm.stopPrank();

        assertEq(streamer.streamBalances(user1), depositAmount);
        assertEq(streamer.lastStreamUpdate(user1), block.timestamp);
    }

    function testTokenStreamerDepositToOtherUser() public {
        uint256 depositAmount = 100 * 10 ** stablecoin.decimals();

        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        streamer.depositToStream(user2, depositAmount);
        vm.stopPrank();

        assertEq(streamer.streamBalances(user2), depositAmount);
        assertEq(streamer.lastStreamUpdate(user2), block.timestamp);
        assertEq(streamer.userStreamRates(user2), depositAmount / streamer.streamDuration());
    }

    function testTokenStreamerWithdraw() public {
        // Setup: deposit tokens and set stream rate
        uint256 depositAmount = 2592000 * 10 ** stablecoin.decimals(); // Large enough to avoid zero rate
        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        streamer.depositToStream(user1, depositAmount);

        // Move time forward
        skip(15 days);

        // Calculate expected withdrawal based on time elapsed
        uint256 streamRate = depositAmount / 30 days; // Rate per second
        uint256 expectedWithdrawal = streamRate * 15 days;
        uint256 balanceBefore = stablecoin.balanceOf(user1);

        // Withdraw
        streamer.withdrawFromStream();
        vm.stopPrank();

        // Verify withdrawal
        assertEq(stablecoin.balanceOf(user1) - balanceBefore, expectedWithdrawal);
        assertEq(streamer.lastStreamUpdate(user1), block.timestamp);
    }

    function testGetStreamRate() public {
        // Setup: deposit tokens
        uint256 depositAmount = 1000 * 10 ** stablecoin.decimals();
        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        streamer.depositToStream(user1, depositAmount);

        uint256 expectedRate = depositAmount / 30 days;
        uint256 rate = streamer.getStreamRate();
        assertEq(rate, expectedRate);
        vm.stopPrank();
    }

    function testGetAvailableTokens() public {
        // Setup: deposit tokens
        uint256 depositAmount = 1000 * 10 ** stablecoin.decimals();
        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        streamer.depositToStream(user1, depositAmount);
        vm.stopPrank();

        // Move time forward
        skip(15 days);

        // Calculate expected available tokens
        uint256 streamRate = depositAmount / 30 days;
        uint256 expectedAvailable = streamRate * 15 days;
        uint256 available = streamer.getAvailableTokens(user1);
        assertEq(available, expectedAvailable);
    }

    function testMaxStreamWithdrawal() public {
        // Setup: deposit tokens
        uint256 depositAmount = 2592000 * 10 ** stablecoin.decimals(); // Large enough to avoid zero rate
        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        streamer.depositToStream(user1, depositAmount);

        // Move time forward beyond stream duration
        skip(31 days);

        // Available tokens should be capped at deposit amount
        uint256 available = streamer.getAvailableTokens(user1);
        assertEq(available, depositAmount);
        vm.stopPrank();
    }

    function test_RevertWhen_DepositTransferFails() public {
        uint256 depositAmount = 1000 * 10 ** stablecoin.decimals();
        vm.startPrank(user1);
        // Don't approve the transfer
        bytes memory err = abi.encodeWithSignature(
            "ERC20InsufficientAllowance(address,uint256,uint256)",
            address(streamer),
            0,
            depositAmount
        );
        vm.expectRevert(err);
        streamer.depositToStream(user1, depositAmount);
        vm.stopPrank();
    }

    function testZeroDeposit() public {
        vm.startPrank(user1);
        stablecoin.approve(address(streamer), 0);
        streamer.depositToStream(user1, 0);
        assertEq(streamer.streamBalances(user1), 0);
        assertEq(streamer.userStreamRates(user1), 0);
        vm.stopPrank();
    }

    function test_RevertWhen_WithdrawWithNoBalance() public {
        vm.startPrank(user1);
        vm.expectRevert("No tokens to withdraw");
        streamer.withdrawFromStream();
        vm.stopPrank();
    }

    function test_RevertWhen_WithdrawTransferFails() public {
        uint256 depositAmount = 2592000 * 10 ** stablecoin.decimals(); // Large enough to avoid zero rate
        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        streamer.depositToStream(user1, depositAmount);

        // Move time forward
        skip(15 days);

        // Mock the transfer to fail
        vm.mockCall(
            address(stablecoin),
            abi.encodeWithSelector(stablecoin.transfer.selector),
            abi.encode(false)
        );

        vm.expectRevert("Transfer failed");
        streamer.withdrawFromStream();

        // Clear the mock
        vm.clearMockedCalls();
        vm.stopPrank();
    }

    function testGetAvailableTokensForNonExistentStream() public {
        assertEq(streamer.getAvailableTokens(address(0)), 0);
    }

    function testMultipleDeposits() public {
        uint256 firstDeposit = 2592000 * 10 ** stablecoin.decimals(); // Large enough to avoid zero rate
        uint256 secondDeposit = 1296000 * 10 ** stablecoin.decimals(); // Large enough to avoid zero rate

        vm.startPrank(user1);
        stablecoin.approve(address(streamer), firstDeposit + secondDeposit);

        // First deposit
        streamer.depositToStream(user1, firstDeposit);
        uint256 firstRate = streamer.userStreamRates(user1);

        // Second deposit (this tests the bug where existing balance is not considered)
        streamer.depositToStream(user1, secondDeposit);
        uint256 secondRate = streamer.userStreamRates(user1);

        assertEq(streamer.streamBalances(user1), firstDeposit + secondDeposit);
        // Bug: rate is calculated only on new deposit, not total balance
        assertEq(secondRate, secondDeposit / streamer.streamDuration());
        // This demonstrates the bug - rate should be based on total balance but isn't
        uint256 correctRate = (firstDeposit + secondDeposit) / streamer.streamDuration();
        assertNotEq(secondRate, correctRate);
        vm.stopPrank();
    }

    function testLowDecimalStreamRateIssue() public {
        // Test the bug where low decimals cause zero stream rates
        uint256 smallAmount = 25 * 10 ** stablecoin.decimals(); // 250 with 1 decimal
        uint256 longDuration = 3 days; // 259200 seconds

        // Deploy streamer with long duration to trigger the bug
        TokenStreamer longStreamer = new TokenStreamer(stablecoin, longDuration);

        vm.startPrank(user1);
        stablecoin.approve(address(longStreamer), smallAmount);
        longStreamer.depositToStream(user1, smallAmount);
        vm.stopPrank();

        // With 1 decimal: 250 / 259200 = 0 (integer division)
        uint256 streamRate = longStreamer.userStreamRates(user1);
        assertEq(streamRate, 0); // This demonstrates the bug
    }

    function testWithdrawExactlyAtStreamDuration() public {
        // Setup: deposit tokens
        uint256 depositAmount = 2592000 * 10 ** stablecoin.decimals(); // Large enough to avoid zero rate
        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        streamer.depositToStream(user1, depositAmount);

        // Move time forward exactly to the stream duration
        skip(30 days);

        uint256 balanceBefore = stablecoin.balanceOf(user1);
        streamer.withdrawFromStream();
        vm.stopPrank();

        // Verify full withdrawal
        assertEq(stablecoin.balanceOf(user1) - balanceBefore, depositAmount);
        assertEq(streamer.streamBalances(user1), 0);
    }

    function testTokensMintedEvent() public {
        uint256 mintAmount = 1000 * 10 ** stablecoin.decimals();

        vm.expectEmit(true, false, false, true);
        emit StableCoin.TokensMinted(user1, mintAmount);

        stablecoin.mint(user1, mintAmount);
    }

    function testStreamDepositEvent() public {
        uint256 depositAmount = 100 * 10 ** stablecoin.decimals();

        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);

        vm.expectEmit(true, true, false, true);
        emit TokenStreamer.StreamDeposit(user1, user1, depositAmount);

        streamer.depositToStream(user1, depositAmount);
        vm.stopPrank();
    }

    function testStreamWithdrawalEvent() public {
        // Setup: deposit tokens
        uint256 depositAmount = 2592000 * 10 ** stablecoin.decimals(); // Large enough to avoid zero rate
        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        streamer.depositToStream(user1, depositAmount);

        // Move time forward
        skip(15 days);

        // Calculate expected withdrawal
        uint256 streamRate = depositAmount / 30 days;
        uint256 expectedWithdrawal = streamRate * 15 days;

        vm.expectEmit(true, false, false, true);
        emit TokenStreamer.StreamWithdrawal(user1, expectedWithdrawal);

        streamer.withdrawFromStream();
        vm.stopPrank();
    }

    function testMintAccessControlIssue() public {
        // Test that anyone can mint (this is the known bug)
        uint256 mintAmount = 1000 * 10 ** stablecoin.decimals();

        // User1 (not owner) can mint tokens to anyone
        vm.prank(user1);
        stablecoin.mint(user2, mintAmount);

        assertEq(stablecoin.balanceOf(user2), (10000000 + 1000) * 10 ** stablecoin.decimals());
    }
}
