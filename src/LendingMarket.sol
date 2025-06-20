// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LiquidityPool.sol";
import "./StableCoin.sol";
import "./GovernanceToken.sol";

contract LendingMarket is Ownable {
    LiquidityPool public immutable pool;
    StableCoin public immutable stablecoin;
    GovernanceToken public immutable govToken;
    TokenStreamer public tokenStreamer;

    uint256 public constant COLLATERAL_RATIO = 150;
    uint256 public constant INTEREST_RATE = 5;
    uint256 public constant LIQUIDATION_BONUS = 5;
    uint256 public constant STREAM_DURATION = 30 days;

    struct Position {
        uint256 collateralAmount;
        uint256 borrowedAmount;
        uint256 lastInterestBlock;
        uint256 marketPrice;
    }

    // Auction struct for liquidated positions
    struct Auction {
        address borrower;
        uint256 collateralAmount;
        uint256 startPrice;
        uint256 endPrice;
        uint256 startTime;
        uint256 endTime;
        bool active;
    }

    mapping(address => Position) public positions;
    mapping(address => uint256) public lastAction;
    mapping(uint256 => Auction) public auctions;
    uint256 public nextAuctionId;

    constructor(address payable _pool) Ownable(msg.sender) {
        pool = LiquidityPool(_pool);
        stablecoin = new StableCoin();
        govToken = new GovernanceToken();

        // Initialize token streamer for reward distribution
        tokenStreamer = new TokenStreamer(stablecoin, STREAM_DURATION);

        // Mint initial governance tokens for protocol operations
        govToken.mint(address(this), 500000 * 10**18);
    }

    // Initialize a new staking group for governance participation
    function createStakingGroup(address[] calldata members, uint256[] calldata weights) external returns (uint256) {
        // Create a new GroupStaking contract for governance token holders
        GroupStaking staking = new GroupStaking(address(govToken));

        // Transfer governance tokens to the staking contract
        govToken.transfer(address(staking), 50000 * 10**18);

        // Create the staking group
        return staking.createStakingGroup(members, weights);
    }

    function initializePosition(uint256 marketPrice) external {
        require(positions[msg.sender].collateralAmount == 0, "Position exists");
        positions[msg.sender].marketPrice = marketPrice;
    }

    function borrow(uint256 borrowAmount) external payable {
        require(msg.value > 0, "Invalid collateral");
        require(borrowAmount > 0, "Invalid borrow amount");
        require(positions[msg.sender].marketPrice > 0, "Position not initialized");

        uint256 requiredCollateral = (borrowAmount * COLLATERAL_RATIO) / 100;
        require(msg.value >= requiredCollateral, "Insufficient collateral");

        positions[msg.sender].collateralAmount += msg.value;
        positions[msg.sender].borrowedAmount += borrowAmount;
        positions[msg.sender].lastInterestBlock = block.number;

        stablecoin.mint(msg.sender, borrowAmount);

        // Reward borrowers with governance tokens based on borrow amount
        uint256 govReward = borrowAmount / 100; // 1% of borrow amount
        if (govReward > 0) {
            govToken.transfer(msg.sender, govReward);
        }
    }

    function repay(uint256 repayAmount) external {
        Position storage position = positions[msg.sender];
        require(position.borrowedAmount > 0, "No active loan");

        uint256 blocksPassed = block.number - position.lastInterestBlock;
        uint256 interest = (position.borrowedAmount * INTEREST_RATE * blocksPassed) / (100 * 100);
        uint256 totalDue = position.borrowedAmount + interest;

        require(repayAmount <= totalDue, "Invalid repay amount");

        require(stablecoin.transferFrom(msg.sender, address(this), repayAmount), "Transfer failed");

        position.borrowedAmount = totalDue - repayAmount;
        position.lastInterestBlock = block.number;

        if (position.borrowedAmount == 0) {
            uint256 collateralToReturn = position.collateralAmount;
            position.collateralAmount = 0;

            (bool success,) = msg.sender.call{value: collateralToReturn}("");
            require(success, "Transfer failed");
        }
    }

    function liquidate(address borrower) external {
        Position storage position = positions[borrower];
        require(position.borrowedAmount > 0, "No active loan");

        uint256 blocksPassed = block.number - position.lastInterestBlock;
        uint256 interest = (position.borrowedAmount * INTEREST_RATE * blocksPassed) / (100 * 100);
        uint256 totalDue = position.borrowedAmount + interest;

        uint256 requiredCollateral = (totalDue * COLLATERAL_RATIO) / 100;
        require(position.collateralAmount < requiredCollateral, "Not liquidatable");

        // Instead of immediate liquidation, create a Dutch auction
        uint256 auctionId = nextAuctionId++;
        uint256 startPrice = position.collateralAmount * 2;
        uint256 endPrice = position.collateralAmount / 2;

        // Create a Dutch auction for the liquidated position
        auctions[auctionId] = Auction({
            borrower: borrower,
            collateralAmount: position.collateralAmount,
            startPrice: startPrice,
            endPrice: endPrice,
            startTime: block.timestamp,
            endTime: block.timestamp + 1 hours, // Short auction duration
            active: true
        });

        // Move collateral to contract and clear position
        uint256 collateralAmount = position.collateralAmount;
        delete positions[borrower];
    }

    // Calculate the current auction price based on time elapsed
    function getCurrentAuctionPrice(uint256 auctionId) public view returns (uint256) {
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction not active");

        if (block.timestamp >= auction.endTime) {
            return auction.endPrice;
        }

        uint256 timeElapsed = block.timestamp - auction.startTime;
        uint256 totalDuration = auction.endTime - auction.startTime;
        uint256 priceDiff = auction.startPrice - auction.endPrice;

        return auction.startPrice - (priceDiff * timeElapsed / totalDuration);
    }

    // Allow users to bid on active auctions
    function bidOnAuction(uint256 auctionId) external payable {
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction not active");
        require(block.timestamp < auction.endTime, "Auction ended");

        uint256 currentPrice = getCurrentAuctionPrice(auctionId);
        require(msg.value >= currentPrice, "Bid too low");

        // Mark auction as inactive
        auction.active = false;

        // Transfer collateral to bidder
        (bool success,) = msg.sender.call{value: auction.collateralAmount}("");
        require(success, "Transfer failed");

        // Refund excess payment
        if (msg.value > currentPrice) {
            uint256 refund = msg.value - currentPrice;
            (bool refundSuccess,) = msg.sender.call{value: refund}("");
            require(refundSuccess, "Refund failed");
        }

        // Reward liquidators with governance tokens
        uint256 govReward = currentPrice / 50; // 2% of liquidation price
        if (govReward > 0) {
            govToken.transfer(msg.sender, govReward);
        }
    }

    // Distribute stablecoin rewards through token streaming
    function distributeRewards(address user, uint256 amount) external onlyOwner {
        require(amount > 0, "Invalid reward amount");

        // Mint stablecoins for rewards
        stablecoin.mint(address(this), amount);

        // Approve and deposit to streamer
        stablecoin.approve(address(tokenStreamer), amount);
        tokenStreamer.depositToStream(amount);
    }

    function getPosition(address user) external view returns (Position memory) {
        return positions[user];
    }

    function getRequiredCollateral(uint256 borrowAmount) public pure returns (uint256) {
        return (borrowAmount * COLLATERAL_RATIO) / 100;
    }

    receive() external payable {}
}
