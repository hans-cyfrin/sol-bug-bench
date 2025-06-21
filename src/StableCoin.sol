// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title StableCoin
 * @dev Implementation of the DeFiHub protocol's native stablecoin
 *
 * This stablecoin uses a simplified decimal structure (1 decimal place)
 * to optimize for gas efficiency and reduce computational complexity.
 * While this differs from the standard 18 decimals, it provides benefits
 * for specific use cases within the protocol.
 */
contract StableCoin is ERC20 {
    // Events for better tracking
    event TokensMinted(address indexed to, uint256 amount);

    /**
     * @dev Initializes the stablecoin with an initial supply
     * The initial supply is allocated to the deployer for distribution
     */
    constructor() ERC20("USD Stable", "USDS") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    /**
     * @dev Override the standard decimals function to use 1 decimal place
     * This design choice optimizes for gas efficiency and simplifies calculations
     * @return The number of decimals used by the token
     */
    function decimals() public view virtual override returns (uint8) {
        return 1; // Using 1 decimal place for gas optimization
    }

    /**
     * @dev Mints new tokens to the specified address
     * In production, this would include access control mechanisms
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }
}

/**
 * @title TokenStreamer
 * @dev Implements a token streaming mechanism for gradual token distribution
 *
 * This contract allows for continuous, time-based distribution of tokens,
 * which is useful for vesting, rewards, and other gradual release scenarios.
 * The streaming rate is determined by the total tokens and duration.
 */
contract TokenStreamer {
    // Core state variables
    StableCoin public immutable token;
    uint256 public streamDuration;

    // User streaming data
    mapping(address => uint256) public streamBalances;
    mapping(address => uint256) public lastStreamUpdate;
    mapping(address => uint256) public userStreamRates;

    // Events for tracking stream activities
    event StreamDeposit(address indexed user, uint256 amount);
    event StreamWithdrawal(address indexed user, uint256 amount);

    /**
     * @dev Initializes the token streamer with a stablecoin and duration
     * @param _token The stablecoin to be streamed
     * @param _streamDuration The duration over which tokens will be streamed
     */
    constructor(StableCoin _token, uint256 _streamDuration) {
        token = _token;
        streamDuration = _streamDuration;
    }

    /**
     * @dev Deposits tokens into the user's streaming balance
     * @param amount The amount of tokens to deposit
     */
    function depositToStream(uint256 amount) external {
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        streamBalances[msg.sender] += amount;
        lastStreamUpdate[msg.sender] = block.timestamp;

        // Calculate stream rate based on deposit amount (per second)
        userStreamRates[msg.sender] = amount / streamDuration;

        emit StreamDeposit(msg.sender, amount);
    }

    /**
     * @dev Withdraws available tokens based on time elapsed since last update
     * The amount withdrawn is calculated based on the streaming rate and time passed
     */
    function withdrawFromStream() external {
        require(streamBalances[msg.sender] > 0, "No tokens to withdraw");
        uint256 secondsElapsed = block.timestamp - lastStreamUpdate[msg.sender];
        uint256 streamRate = userStreamRates[msg.sender];

        // If beyond stream duration, withdraw all remaining tokens
        if (secondsElapsed >= streamDuration) {
            uint256 amount = streamBalances[msg.sender];
            streamBalances[msg.sender] = 0;
            lastStreamUpdate[msg.sender] = block.timestamp;

            require(token.transfer(msg.sender, amount), "Transfer failed");
            emit StreamWithdrawal(msg.sender, amount);
            return;
        }

        // Calculate amount based on stream rate and elapsed time
        uint256 amount = streamRate * secondsElapsed;
        require(amount <= streamBalances[msg.sender], "Insufficient balance");

        // Update state
        streamBalances[msg.sender] -= amount;
        lastStreamUpdate[msg.sender] = block.timestamp;

        require(token.transfer(msg.sender, amount), "Transfer failed");
        emit StreamWithdrawal(msg.sender, amount);
    }

    /**
     * @dev Returns the current streaming rate in tokens per second
     * @return The number of tokens released per second
     */
    function getStreamRate() external view returns (uint256) {
        return userStreamRates[msg.sender];
    }

    /**
     * @dev Calculates the amount of tokens available for withdrawal
     * @param user The address to check available tokens for
     * @return The amount of tokens available for withdrawal
     */
    function getAvailableTokens(address user) external view returns (uint256) {
        if (streamBalances[user] == 0) return 0;

        uint256 secondsElapsed = block.timestamp - lastStreamUpdate[user];
        uint256 streamRate = userStreamRates[user];

        // If beyond stream duration, return all remaining tokens
        if (secondsElapsed >= streamDuration) {
            return streamBalances[user];
        }

        // Calculate amount based on stream rate and elapsed time
        uint256 amount = streamRate * secondsElapsed;
        return amount <= streamBalances[user] ? amount : streamBalances[user];
    }
}
