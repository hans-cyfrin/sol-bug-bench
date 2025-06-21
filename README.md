# Solidity Bug Bench

## Purpose
This repository contains a collection of intentionally vulnerable Solidity smart contracts designed for educational and testing purposes. It serves as a resource for developers, security researchers, and students to learn about common vulnerabilities in smart contracts and how to mitigate them.

## Bug Categories and Locations

### 1. Denial of Service (DoS) Attacks

| Check Item | Bug Location | Contract | Function |
|------------|--------------|----------|----------|
| SOL-AM-DOSA-1 | ✓ | LiquidityPool.sol | `claimReward` - Transfers fees to owner before user payment |
| SOL-AM-DOSA-2 | ✓ | LendingMarket.sol | `liquidate` - No check if ETH transfer might fail |
| SOL-AM-DOSA-3 | ✓ | GovernanceToken.sol | `withdrawFromGroup` - Blacklisted member blocks all distributions |
| SOL-AM-DOSA-4 | ✓ | LiquidityPool.sol | `processWithdrawals` - Single failure blocks entire queue |
| SOL-AM-DOSA-5 | ✓ | StableCoin.sol | `TokenStreamer` - Integer division with low decimals |

### 2. Reentrancy Attacks

| Check Item | Bug Location | Contract | Function |
|------------|--------------|----------|----------|
| SOL-AM-ReentrancyAttack-1 | ✓ | LendingMarket.sol | `repay` - ETH transfer before state update |
| SOL-AM-ReentrancyAttack-2 | ✓ | LiquidityPool.sol | `withdraw` - Token transfer before state update |

### 3. Front-running Attacks

| Check Item | Bug Location | Contract | Function |
|------------|--------------|----------|----------|
| SOL-AM-FrA-1 | ✓ | LiquidityPool.sol | `createMarket` - Manipulable market creation |
| SOL-AM-FrA-2 | ✓ | LendingMarket.sol | `initializePosition` - Manipulable position initialization |
| SOL-AM-FrA-3 | ✓ | LendingMarket.sol | `bidOnAuction` - Auction bid front-running |
| SOL-AM-FrA-4 | ✓ | LiquidityPool.sol | `claimReward` - Reward claim front-running |

### 4. Replay Attacks

| Check Item | Bug Location | Contract | Function |
|------------|--------------|----------|----------|
| SOL-AM-ReplayAttack-1 | ✓ | LiquidityPool.sol | `claimReward` - Nonce only incremented on success |
| SOL-AM-ReplayAttack-2 | ✓ | LiquidityPool.sol | `claimReward` - No contract-specific data in signature |

### 5. Griefing Attacks

| Check Item | Bug Location | Contract | Function |
|------------|--------------|----------|----------|
| SOL-AM-GA-1 | ✓ | LiquidityPool.sol | `depositFor` - Anyone can reset withdrawal timer |
| SOL-AM-GA-2 | ✓ | GovernanceToken.sol | `withdrawFromGroup` - Blacklisted member blocks distributions |

### 6. Price Manipulation Attacks

| Check Item | Bug Location | Contract | Function |
|------------|--------------|----------|----------|
| SOL-AM-PMA-1 | ✓ | LendingMarket.sol | `borrow` - Relies on user-provided price |
| SOL-AM-PMA-1_0 | ✓ | LendingMarket.sol | `getCurrentAuctionPrice` - Manipulable price calculation |
| SOL-AM-PMA-2_1 | ✓ | LendingMarket.sol | `liquidate` - No oracle verification for liquidations |

### 7. Donation Attacks

| Check Item | Bug Location | Contract | Function |
|------------|--------------|----------|----------|
| SOL-AM-DA-1 | ✓ | LiquidityPool.sol | `deposit` - Share calculation vulnerable to donations |

### 8. Timestamp Manipulation

| Check Item | Bug Location | Contract | Function |
|------------|--------------|----------|----------|
| SOL-AM-MA-1 | ✓ | LendingMarket.sol | `bidOnAuction` - Relies on block.timestamp |
| SOL-AM-MA-2 | ✓ | LiquidityPool.sol | `withdraw` - Withdrawal delay uses block.timestamp |
| SOL-AM-MA-3 | ✓ | StableCoin.sol | `withdrawFromStream` - Streaming calculation uses block.timestamp |

### 9. Additional Bugs

| Bug Type | Bug Location | Contract | Function |
|----------|--------------|----------|----------|
| Access Control | ✓ | StableCoin.sol | `mint` - No access control |
| Return Value | ✓ | LendingMarket.sol | `borrow` - Unchecked mint return value |
| Input Validation | ✓ | LendingMarket.sol | `initializePosition` - No price validation |