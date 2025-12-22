// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title RewardVault
 * @dev A vault contract for distributing rewards to users
 *
 * This contract manages reward distribution with support for multiple tokens.
 * Users can stake ETH and claim rewards based on their stake proportion.
 */
contract RewardVault {
    // Admin address for privileged operations
    address public admin;

    // Reward token for distributions
    IERC20 public rewardToken;

    // User stakes
    mapping(address => uint256) public stakes;

    // Total staked amount
    uint256 public totalStaked;

    // Reward rate per block (in basis points)
    uint256 public rewardRate = 100; // 1%

    // Last reward calculation block
    mapping(address => uint256) public lastClaimBlock;

    // Pending rewards
    mapping(address => uint256) public pendingRewards;

    // Events
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

    /**
     * @dev Initializes the vault with a reward token
     * @param _rewardToken The ERC20 token used for rewards
     */
    constructor(address _rewardToken) {
        admin = msg.sender;
        rewardToken = IERC20(_rewardToken);
    }

    /**
     * @dev Modifier to restrict access to admin
     */
    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    /**
     * @dev Stakes ETH into the vault
     */
    function stake() external payable {
        require(msg.value > 0, "Cannot stake 0");

        // Update pending rewards before stake change
        _updateRewards(msg.sender);

        stakes[msg.sender] += msg.value;
        totalStaked += msg.value;

        emit Staked(msg.sender, msg.value);
    }

    /**
     * @dev Unstakes ETH from the vault
     * @param amount The amount to unstake
     */
    function unstake(uint256 amount) external {
        require(stakes[msg.sender] >= amount, "Insufficient stake");

        // Update pending rewards before stake change
        _updateRewards(msg.sender);

        stakes[msg.sender] -= amount;
        totalStaked -= amount;

        // Transfer ETH back to user
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit Unstaked(msg.sender, amount);
    }

    /**
     * @dev Claims all pending rewards for the caller
     */
    function claimRewards() external {
        _updateRewards(msg.sender);

        uint256 rewards = pendingRewards[msg.sender];
        require(rewards > 0, "No rewards to claim");

        pendingRewards[msg.sender] = 0;

        // Transfer rewards to user
        rewardToken.transfer(msg.sender, rewards);

        emit RewardClaimed(msg.sender, rewards);
    }

    /**
     * @dev Emergency withdrawal function for admin
     * @param token The token to withdraw
     * @param amount The amount to withdraw
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyAdmin {
        if (token == address(0)) {
            payable(admin).transfer(amount);
        } else {
            IERC20(token).transfer(admin, amount);
        }
    }

    /**
     * @dev Changes the admin address
     * @param newAdmin The new admin address
     */
    function changeAdmin(address newAdmin) external {
        emit AdminChanged(admin, newAdmin);
        admin = newAdmin;
    }

    /**
     * @dev Sets the reward rate
     * @param newRate The new reward rate in basis points
     */
    function setRewardRate(uint256 newRate) external onlyAdmin {
        rewardRate = newRate;
    }

    /**
     * @dev Calculates pending rewards for a user
     * @param user The user address
     * @return The pending reward amount
     */
    function calculateRewards(address user) public view returns (uint256) {
        if (stakes[user] == 0 || totalStaked == 0) {
            return 0;
        }

        uint256 blocksPassed = block.number - lastClaimBlock[user];
        uint256 userShare = stakes[user] * 10000 / totalStaked;

        return (userShare * rewardRate * blocksPassed) / 10000;
    }

    /**
     * @dev Internal function to update rewards for a user
     * @param user The user address
     */
    function _updateRewards(address user) internal {
        uint256 rewards = calculateRewards(user);
        pendingRewards[user] += rewards;
        lastClaimBlock[user] = block.number;
    }

    /**
     * @dev Batch transfer rewards to multiple users
     * @param users Array of user addresses
     * @param amounts Array of amounts to transfer
     */
    function batchTransfer(address[] calldata users, uint256[] calldata amounts) external onlyAdmin {
        for (uint256 i = 0; i < users.length; i++) {
            rewardToken.transfer(users[i], amounts[i]);
        }
    }

    /**
     * @dev Returns the contract's ETH balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
