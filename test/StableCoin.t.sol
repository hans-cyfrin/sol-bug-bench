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

        // Transfer some tokens to users for testing
        stablecoin.transfer(user1, 1000 * 10**stablecoin.decimals());
        stablecoin.transfer(user2, 1000 * 10**stablecoin.decimals());
    }

    function testInitialSupply() public {
        assertEq(stablecoin.totalSupply(), 1000000 * 10**stablecoin.decimals());
        assertEq(stablecoin.balanceOf(owner), 998000 * 10**stablecoin.decimals());
    }

    function testDecimals() public {
        assertEq(stablecoin.decimals(), 1);
    }

    function testMint() public {
        uint256 mintAmount = 1000 * 10**stablecoin.decimals();
        stablecoin.mint(user1, mintAmount);
        assertEq(stablecoin.balanceOf(user1), 2000 * 10**stablecoin.decimals());
    }

    function testTokenStreamerDeposit() public {
        uint256 depositAmount = 100 * 10**stablecoin.decimals();

        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        streamer.depositToStream(depositAmount);
        vm.stopPrank();

        assertEq(streamer.streamBalances(user1), depositAmount);
        assertEq(streamer.lastStreamUpdate(user1), block.timestamp);
    }

    function testTokenStreamerWithdraw() public {
        // Setup: deposit tokens and set stream rate
        uint256 depositAmount = 1000 * 10**stablecoin.decimals();
        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        streamer.depositToStream(depositAmount);

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
        uint256 depositAmount = 1000 * 10**stablecoin.decimals();
        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        streamer.depositToStream(depositAmount);
        vm.stopPrank();

        uint256 expectedRate = depositAmount / 30 days;
        uint256 rate = streamer.getStreamRate();
        assertEq(rate, expectedRate);
    }

    function testGetAvailableTokens() public {
        // Setup: deposit tokens
        uint256 depositAmount = 1000 * 10**stablecoin.decimals();
        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        streamer.depositToStream(depositAmount);
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
        uint256 depositAmount = 1000 * 10**stablecoin.decimals();
        vm.startPrank(user1);
        stablecoin.approve(address(streamer), depositAmount);
        streamer.depositToStream(depositAmount);

        // Move time forward beyond stream duration
        skip(31 days);

        // Available tokens should be capped at deposit amount
        uint256 available = streamer.getAvailableTokens(user1);
        assertEq(available, depositAmount);
        vm.stopPrank();
    }
}
