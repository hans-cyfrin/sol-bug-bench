# Solidity Bug Bench

## Purpose
This repository contains a collection of intentionally vulnerable Solidity smart contracts designed for educational and testing purposes. It serves as a resource for developers, security researchers, and students to learn about common vulnerabilities in smart contracts and how to mitigate them.

## Current Architecture

The project consists of three main contracts:
- **GovernanceToken.sol** - Contains both `GovernanceToken` and `GroupStaking` contracts
- **LiquidityPool.sol** - Contains both `PoolShare` and `LiquidityPool` contracts
- **StableCoin.sol** - Contains both `StableCoin` and `TokenStreamer` contracts

## Detailed Bug Descriptions

### Denial of Service (DoS) Attacks

**SOL-AM-DOSA-1**: In `LiquidityPool.claimReward()`, the function transfers fees to the owner before transferring rewards to the user. If the owner's transfer fails, the user cannot claim rewards.

**SOL-AM-DOSA-3**: In `GroupStaking.withdrawFromGroup()`, if any member of a group is blacklisted, the entire group's funds become locked because the transfer to the blacklisted member will fail, preventing all withdrawals.

**SOL-AM-DOSA-5**: In `TokenStreamer.depositToStream()`, integer division with low decimals (1 decimal place) can result in zero stream rates, preventing any token streaming.

### Access Control Issues

**Access Control Bug**: The `StableCoin.mint()` function has no access control, allowing anyone to mint unlimited tokens to any address.

### Logic Errors

**Stream Rate Calculation**: In `TokenStreamer.depositToStream()`, the stream rate is calculated only based on the new deposit amount, not the total balance, leading to incorrect streaming rates for subsequent deposits.

## Testing

Run the test suite with:
```bash
forge test
```

Individual contract tests:
```bash
forge test --match-contract GovernanceTokenTest
forge test --match-contract LiquidityPoolTest
forge test --match-contract StableCoinTest
```

## Educational Use

This repository is designed for:
- Smart contract security training
- Vulnerability research and detection tool testing
- Educational workshops on blockchain security
- Bug bounty preparation

**⚠️ Warning**: These contracts contain intentional vulnerabilities and should never be deployed to mainnet or used with real funds.