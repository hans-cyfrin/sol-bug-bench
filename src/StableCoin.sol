// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title StableCoin
 * @dev Implementation of the DeFiHub protocol's native stablecoin
 *
 * This stablecoin uses a simplified decimal structure (1 decimal place)
 * to optimize for gas efficiency and reduce computational complexity.
 * The design choice provides significant gas savings for frequent transactions
 * within the DeFiHub ecosystem.
 */
contract StableCoin is ERC20 {
    // Events for comprehensive transaction tracking
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
     * Allows flexible token supply management for protocol operations
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
 * This contract enables continuous, time-based distribution of tokens,
 * which is essential for vesting schedules, reward programs, and other
 * gradual release scenarios within the DeFiHub ecosystem.
 */
contract TokenStreamer {
    // Core state variables
    StableCoin public immutable token;
    uint256 public streamDuration;

    // Constants
    uint256 public constant STREAM_MIN_DURATION = 3600; // 1 hour
    uint256 public constant STREAM_MAX_DURATION = 3600 * 24 * 365; // 1 year

    // User streaming data for efficient tracking
    mapping(address => uint256) public streamBalances;
    mapping(address => uint256) public lastStreamUpdate;
    mapping(address => uint256) public userStreamRates;

    // Events for tracking stream activities
    event StreamDeposit(address indexed depositor, address indexed to, uint256 amount);
    event StreamWithdrawal(address indexed user, uint256 amount);

    // Errors
    error InvalidTokenAddress();
    error InvalidStreamDuration();

    /**
     * @dev Initializes the token streamer with a stablecoin and duration
     * @param _token The stablecoin to be streamed
     * @param _streamDuration The duration over which tokens will be streamed
     */
    constructor(StableCoin _token, uint256 _streamDuration) {
        if (address(_token) == address(0)) {
            revert InvalidTokenAddress();
        }
        if (
            _streamDuration < STREAM_MIN_DURATION
                || _streamDuration > STREAM_MAX_DURATION
        ) {
            revert InvalidStreamDuration();
        }

        token = _token;
        streamDuration = _streamDuration;
    }

    /**
     * @dev Deposits tokens into the user's streaming balance
     * Sets up a linear release schedule over the configured duration
     * @param to The address that will receive the streamed tokens
     * @param amount The amount of tokens to deposit for streaming
     */
    function depositToStream(address to, uint256 amount) external {
        require(to != address(0), "Invalid address");
        require(amount > 0, "Amount must be greater than 0");
        require(
            token.transferFrom(msg.sender, address(this), amount), "Transfer failed"
        );
        streamBalances[to] += amount;
        lastStreamUpdate[to] = block.timestamp;

        // Calculate stream rate based on deposit amount (per second)
        userStreamRates[to] = amount / streamDuration;
        emit StreamDeposit(msg.sender, to, amount);
    }

    /**
     * @dev Withdraws available tokens based on time elapsed since last update
     * The amount withdrawn is calculated based on the streaming rate and time passed
     */
    function withdrawFromStream() external {
        uint256 amount = getAvailableTokens(msg.sender);
        require(amount > 0, "No tokens to withdraw");

        // Update state to reflect withdrawal
        streamBalances[msg.sender] -= amount;
        lastStreamUpdate[msg.sender] = block.timestamp;

        require(token.transfer(msg.sender, amount), "Transfer failed");
        emit StreamWithdrawal(msg.sender, amount);
    }

    /**
     * @dev Returns the current streaming rate in tokens per second
     * @return The number of tokens released per second for the caller
     */
    function getStreamRate() external view returns (uint256) {
        return userStreamRates[msg.sender];
    }

    /**
     * @dev Calculates the amount of tokens available for withdrawal
     * @param user The address to check available tokens for
     * @return amount The amount of tokens available for withdrawal
     */
    function getAvailableTokens(address user) public view returns (uint256 amount) {
        uint256 secondsElapsed = block.timestamp - lastStreamUpdate[user];
        uint256 streamRate = userStreamRates[user];

        // Calculate amount based on stream rate and elapsed time
        amount = streamRate * secondsElapsed;
        if (amount > streamBalances[user]) {
            amount = streamBalances[user];
        }
        return amount;
    }
}
