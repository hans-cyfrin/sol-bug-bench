// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/LendingMarket.sol";
import "../src/LiquidityPool.sol";

contract LendingMarketTest is Test {
    LendingMarket public market;
    LiquidityPool public pool;
    address public owner;
    address public user1;
    address public user2;

    struct Auction {
        address borrower;
        uint256 collateralAmount;
        uint256 startPrice;
        uint256 endPrice;
        uint256 startTime;
        uint256 endTime;
        bool active;
    }

    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy contracts
        pool = new LiquidityPool();
        market = new LendingMarket(payable(address(pool)));

        // Fund users
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function testInitializePosition() public {
        vm.prank(user1);
        market.initializePosition(1000); // Price of 1000

        (uint256 collateral, uint256 borrowed, uint256 lastInterest, uint256 marketPrice) = market.positions(user1);
        assertEq(collateral, 0);
        assertEq(borrowed, 0);
        assertEq(lastInterest, 0);
        assertEq(marketPrice, 1000);
    }

    function testBorrow() public {
        // Initialize position
        vm.startPrank(user1);
        market.initializePosition(1000);

        // Borrow with collateral
        uint256 borrowAmount = 1 ether;
        uint256 collateralRequired = market.getRequiredCollateral(borrowAmount);
        market.borrow{value: collateralRequired}(borrowAmount);
        vm.stopPrank();

        // Verify position
        (uint256 collateral, uint256 borrowed,,) = market.positions(user1);
        assertEq(collateral, collateralRequired);
        assertEq(borrowed, borrowAmount);

        // Verify stablecoin balance
        assertEq(market.stablecoin().balanceOf(user1), borrowAmount);
    }

    function testRepay() public {
        // Setup: Initialize and borrow
        vm.startPrank(user1);
        market.initializePosition(1000);
        uint256 borrowAmount = 1 ether;
        uint256 collateralRequired = market.getRequiredCollateral(borrowAmount);
        market.borrow{value: collateralRequired}(borrowAmount);

        // Approve and repay
        market.stablecoin().approve(address(market), borrowAmount);
        market.repay(borrowAmount);
        vm.stopPrank();

        // Verify position is cleared
        (uint256 collateral, uint256 borrowed,,) = market.positions(user1);
        assertEq(collateral, 0);
        assertEq(borrowed, 0);
    }

    function testLiquidation() public {
        // Setup: Initialize and borrow
        vm.startPrank(user1);
        market.initializePosition(1000);
        uint256 borrowAmount = 1 ether;
        uint256 collateralRequired = market.getRequiredCollateral(borrowAmount);
        market.borrow{value: collateralRequired}(borrowAmount);
        vm.stopPrank();

        // Simulate price drop to make position liquidatable
        vm.roll(block.number + 1000); // Move blocks forward for interest accrual

        // Trigger liquidation
        vm.prank(user2);
        market.liquidate(user1);

        // Verify auction created
        (
            address borrower,
            uint256 collateralAmount,
            ,
            ,
            ,
            ,
            bool active
        ) = market.auctions(0);
        assertEq(borrower, user1);
        assertEq(collateralAmount, collateralRequired);
        assertTrue(active);
    }

    function testAuctionBidding() public {
        // Setup: Create an auction (using previous test)
        testLiquidation();

        // Get current auction price
        uint256 currentPrice = market.getCurrentAuctionPrice(0);

        // Place winning bid
        vm.prank(user2);
        market.bidOnAuction{value: currentPrice}(0);

        // Verify auction completed
        (,,,,,, bool active) = market.auctions(0);
        assertFalse(active);
    }

    function testCreateStakingGroup() public {
        address[] memory members = new address[](2);
        members[0] = user1;
        members[1] = user2;

        uint256[] memory weights = new uint256[](2);
        weights[0] = 60;
        weights[1] = 40;

        uint256 groupId = market.createStakingGroup(members, weights);
        assertGt(groupId, 0);
    }

    function testDistributeRewards() public {
        // Mint some tokens to the market for rewards
        market.stablecoin().mint(address(market), 10000);

        // Need to approve from the market's address
        vm.prank(address(market));
        market.stablecoin().approve(address(market.tokenStreamer()), 1000);

        vm.prank(owner);
        market.distributeRewards(user1, 1000);

        // Verify rewards were distributed
        assertEq(market.stablecoin().balanceOf(address(market.tokenStreamer())), 1000);
    }

    receive() external payable {}
}
