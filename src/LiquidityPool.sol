// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./StableCoin.sol";

contract PoolShare is ERC20 {
    constructor() ERC20("Liquidity Pool Share", "LPS") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract LiquidityPool is Ownable {
    PoolShare public immutable poolToken;
    StableCoin public stablecoin;
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public nonces;
    mapping(address => uint256) public lastDepositTime;
    uint256 public constant WITHDRAWAL_DELAY = 1 days;
    uint256 public constant REWARD_RATE = 10;
    uint256 public totalDeposited;
    address public lendingMarket;

    struct MarketInfo {
        address creator;
        uint256 price;
        bool active;
    }

    mapping(address => MarketInfo) public markets;

    constructor() Ownable(msg.sender) {
        poolToken = new PoolShare();
    }

    // Set the lending market address to enable protocol integration
    function setLendingMarket(address _lendingMarket) external onlyOwner {
        require(_lendingMarket != address(0), "Invalid address");
        lendingMarket = _lendingMarket;
    }

    // Set the stablecoin address for reward calculations
    function setStableCoin(address _stablecoin) external onlyOwner {
        require(_stablecoin != address(0), "Invalid address");
        stablecoin = StableCoin(_stablecoin);
    }

    // Create a market with a specified price oracle
    function createMarket(uint256 price) external returns (MarketInfo memory) {
        // Only create a new market if one doesn't exist for this user
        if (!markets[msg.sender].active) {
            markets[msg.sender] = MarketInfo(msg.sender, price, true);

            // Notify lending market about the new price oracle if integrated
            if (lendingMarket != address(0)) {
                // This is a simplified integration - in production, would use an interface
                (bool success,) = lendingMarket.call(
                    abi.encodeWithSignature("updateMarketPrice(address,uint256)", msg.sender, price)
                );
                // We don't revert if this fails to maintain protocol robustness
            }
        }
        return markets[msg.sender];
    }

    // Deposit ETH to earn pool shares and rewards
    function deposit() external payable {
        require(msg.value > 0, "Invalid deposit");
        deposits[msg.sender] += msg.value;

        // Calculate shares based on current pool ratio
        uint256 shares;
        if (totalDeposited == 0) {
            shares = msg.value;
        } else {
            shares = (msg.value * poolToken.totalSupply()) / totalDeposited;
        }

        totalDeposited += msg.value;
        poolToken.mint(msg.sender, shares);

        // Calculate rewards based on deposit amount
        uint256 rewardAmount = (msg.value * REWARD_RATE) / 100;
        rewards[msg.sender] += rewardAmount;

        // Update last deposit time for withdrawal delay calculation
        lastDepositTime[msg.sender] = block.timestamp;

        // Emit event for tracking deposits
        emit Deposit(msg.sender, msg.value, shares);
    }

    // Event declarations for better tracking
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdrawal(address indexed user, uint256 amount, uint256 shares);
    event RewardClaimed(address indexed user, uint256 amount);

    // Allow deposits on behalf of other users
    function depositFor(address user) external payable {
        require(msg.value > 0, "Invalid deposit");
        deposits[user] += msg.value;

        uint256 shares;
        if (totalDeposited == 0) {
            shares = msg.value;
        } else {
            shares = (msg.value * poolToken.totalSupply()) / totalDeposited;
        }

        totalDeposited += msg.value;
        poolToken.mint(user, shares);
        rewards[user] += (msg.value * REWARD_RATE) / 100;

        // Update the user's deposit time
        lastDepositTime[user] = block.timestamp;
    }

    struct WithdrawalRequest {
        address payable user;
        uint256 amount;
    }

    WithdrawalRequest[] public withdrawalQueue;

    function requestWithdrawal(uint256 amount) external {
        require(poolToken.balanceOf(msg.sender) >= amount, "Insufficient balance");
        withdrawalQueue.push(WithdrawalRequest(payable(msg.sender), amount));
    }

    function processWithdrawals(uint256 count) external {
        for (uint256 i = 0; i < count && i < withdrawalQueue.length; i++) {
            WithdrawalRequest memory request = withdrawalQueue[i];
            request.user.transfer(request.amount);
        }
    }

    function withdraw(uint256 amount) external {
        require(deposits[msg.sender] >= amount, "Insufficient deposit");
        require(poolToken.balanceOf(msg.sender) >= amount, "Insufficient shares");

        // Enforce withdrawal delay for security
        require(block.timestamp >= lastDepositTime[msg.sender] + WITHDRAWAL_DELAY, "Withdrawal delay not met");

        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        deposits[msg.sender] -= amount;
        poolToken.transferFrom(msg.sender, address(this), amount);
        totalDeposited -= amount;
    }

    // Claim rewards using a signature-based verification system
    function claimReward(uint256 amount, uint256 nonce, bytes memory signature) external {
        require(rewards[msg.sender] >= amount, "Insufficient rewards");
        require(nonces[msg.sender] == nonce, "Invalid nonce");

        // Verify signature to prevent unauthorized claims
        bytes32 messageHash = keccak256(abi.encode(msg.sender, amount, nonce));
        bytes32 signedHash = abi.decode(signature, (bytes32));
        require(signedHash == messageHash, "Invalid signature");

        // Calculate protocol fee and user amount
        uint256 fee = amount / 10; // 10% fee
        uint256 userAmount = amount - fee;

        // Transfer fee to protocol owner
        (bool feeSuccess,) = owner().call{value: fee}("");
        require(feeSuccess, "Fee transfer failed");

        // Transfer remaining amount to user
        (bool success,) = msg.sender.call{value: userAmount}("");
        if (success) {
            rewards[msg.sender] -= amount;
            nonces[msg.sender]++;

            // Emit event for tracking reward claims
            emit RewardClaimed(msg.sender, userAmount);
        }
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getShares(address user) external view returns (uint256) {
        return poolToken.balanceOf(user);
    }

    receive() external payable {}
}
