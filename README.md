# Vault-Forge: Liquid Staking Derivative with Reputation System

A comprehensive decentralized finance (DeFi) platform built on the Stacks blockchain that combines liquid staking derivatives with an integrated on-chain reputation system. Vault-Forge enables users to stake STX tokens while maintaining liquidity through derivative tokens, all governed by a dynamic reputation-based system.

## 🌟 Features

### Liquid Staking
- **Multi-Pool Support**: Create and manage multiple staking pools for different assets/positions
- **Liquid Derivatives**: Receive tradeable liquid tokens (1:1 ratio) when staking STX
- **Flexible Unstaking**: Burn liquid tokens to retrieve staked STX at any time
- **Minimum Stake**: 1 STX minimum to prevent spam and ensure meaningful participation

### Reputation System
- **Dynamic Scoring**: On-chain reputation scores that evolve based on user actions
- **Decay Mechanism**: Reputation naturally decays over time to maintain active participation
- **Social Features**: Users can endorse trustworthy participants or report malicious behavior
- **Access Control**: Certain high-impact actions require minimum reputation thresholds
- **Staking Bonus**: Additional reputation earned based on total staked amounts

### Governance & Security
- **Admin Controls**: Emergency pause functionality and parameter adjustments
- **Comprehensive Error Handling**: Detailed error codes for all failure scenarios
- **Balance Validation**: Thorough checks on all financial operations
- **Event Tracking**: Complete on-chain audit trail of all reputation events

## 📋 Contract Overview

### Core Components

1. **Staking Pools**: Individual pools for different staking strategies
2. **User Stakes**: Track individual user positions across pools  
3. **Liquid Balances**: Manage derivative token balances
4. **Reputation System**: Score tracking and event logging
5. **Admin Functions**: Contract governance and emergency controls

### Key Constants

```clarity
MIN-STAKE: 1,000,000 micro-STX (1 STX)
REPUTATION-DECAY-BLOCKS: 144 blocks (~1 day)
DEFAULT-REPUTATION: 50 points
REPUTATION-THRESHOLD: 50 points (for pool creation)
```

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet with STX tokens
- Basic understanding of Clarity smart contracts

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd vault-forge
```

2. Check contract syntax:
```bash
clarinet check
```

3. Run tests:
```bash
npm install
npm test
```

### Deployment

1. Configure your deployment settings in `Clarinet.toml`
2. Deploy to testnet:
```bash
clarinet deploy --testnet
```

## 📖 Usage Guide

### For Stakers

#### Creating a Pool
```clarity
(contract-call? .vault-forge create-pool "My Staking Pool")
```
- Requires minimum reputation of 50 points
- Returns a unique pool ID
- Earns +10 reputation points

#### Staking STX
```clarity
(contract-call? .vault-forge stake u1 u1000000) ;; Stake 1 STX in pool 1
```
- Minimum stake: 1 STX (1,000,000 micro-STX)
- Receives liquid derivative tokens 1:1
- Earns +5 reputation points

#### Unstaking
```clarity
(contract-call? .vault-forge unstake u1 u500000) ;; Unstake 0.5 liquid tokens
```
- Burns liquid tokens to retrieve STX
- Exchange rate based on pool performance
- Earns +2 reputation points

### Reputation Management

#### Endorsing Users
```clarity
(contract-call? .vault-forge endorse-user 'SP1234...)
```
- Requires 75+ reputation to endorse
- Target user gains +5 reputation
- Endorser gains +1 reputation

#### Reporting Malicious Behavior  
```clarity
(contract-call? .vault-forge report-user 'SP1234... "Spam behavior")
```
- Requires 75+ reputation to report
- Reported user loses -10 reputation
- Reporter gains +2 reputation

## 📊 Read-Only Functions

### User Information
```clarity
;; Get user's reputation score
(contract-call? .vault-forge get-reputation 'SP1234...)

;; Get detailed reputation data
(contract-call? .vault-forge get-reputation-details 'SP1234...)

;; Get user's stake in a specific pool
(contract-call? .vault-forge get-user-stake 'SP1234... u1)

;; Get liquid token balance
(contract-call? .vault-forge get-liquid-balance 'SP1234... u1)
```

### Pool Information
```clarity
;; Get pool details
(contract-call? .vault-forge get-pool-info u1)

;; Get contract statistics
(contract-call? .vault-forge get-contract-stats)
```

## ⚙️ Admin Functions

Only the contract owner can execute these functions:

### Emergency Controls
```clarity
;; Pause all contract operations
(contract-call? .vault-forge set-contract-pause true)

;; Update reward rate (basis points)
(contract-call? .vault-forge set-reward-rate u600) ;; 6% annual

;; Adjust reputation threshold
(contract-call? .vault-forge set-reputation-threshold u75)
```

## 🏗️ Architecture

### Data Structures

#### Staking Pools
```clarity
{
  name: string-ascii 50,
  total-staked: uint,
  total-liquid-tokens: uint, 
  active: bool,
  creator: principal,
  created-at: uint
}
```

#### User Stakes
```clarity
{
  staked-amount: uint,
  liquid-tokens: uint,
  last-claim: uint,
  entry-block: uint
}
```

#### Reputation Data
```clarity
{
  score: uint,
  total-interactions: uint,
  successful-interactions: uint,
  last-update: uint,
  staking-bonus: uint
}
```

### Reputation Actions & Rewards

| Action | Reputation Impact | Requirements |
|--------|------------------|--------------|
| Pool Creation | +10 points | 50+ reputation |
| Staking | +5 points | 1+ STX |
| Unstaking | +2 points | Liquid tokens |
| Endorsing | +1 point (endorser), +5 points (target) | 75+ reputation |
| Reporting | +2 points (reporter), -10 points (target) | 75+ reputation |
| Staking Bonus | +1 point per 1 STX staked | Automatic |

## 🔒 Security Features

### Input Validation
- Amount checks for all financial operations
- Balance verification before transfers
- Pool existence validation
- Reputation threshold enforcement

### Error Handling
```clarity
ERR-UNAUTHORIZED (401): Insufficient permissions
ERR-INSUFFICIENT-BALANCE (402): Not enough tokens/STX
ERR-INVALID-AMOUNT (403): Invalid stake/unstake amount
ERR-POOL-NOT-FOUND (404): Pool doesn't exist
ERR-ALREADY-EXISTS (405): Duplicate creation attempt
ERR-INVALID-REPUTATION (406): Reputation too low
ERR-COOLDOWN-ACTIVE (407): Action on cooldown
```

### Access Controls
- Owner-only admin functions
- Reputation-gated pool creation
- Minimum stake requirements
- Self-action prevention (can't endorse/report yourself)

## 🧪 Testing

### Unit Tests
The contract includes comprehensive test coverage for:
- Staking and unstaking flows
- Reputation calculations and updates
- Pool creation and management
- Error conditions and edge cases
- Admin function permissions

### Test Scenarios
```bash
# Run all tests
npm test

# Run specific test suite
npm test -- --grep "staking"
npm test -- --grep "reputation"
npm test -- --grep "admin"
```

## 🚨 Risk Considerations

### Smart Contract Risks
- **Code Bugs**: Thoroughly tested but not formally audited
- **Upgrade Risk**: Contract is immutable once deployed
- **Admin Keys**: Owner has emergency pause powers

### Economic Risks
- **Liquidity Risk**: Unstaking depends on contract STX balance
- **Reputation Gaming**: Users might attempt to manipulate scores
- **Pool Risk**: Individual pools may have different risk profiles

### Mitigation Strategies
- Minimum stake requirements prevent spam
- Reputation decay prevents score hoarding
- Emergency pause for critical issues
- Comprehensive error handling

## 🛣️ Roadmap

### Phase 1 (Current)
- ✅ Basic liquid staking functionality
- ✅ Reputation system implementation
- ✅ Multi-pool support
- ✅ Social features (endorse/report)

### Phase 2 (Planned)
- 🔄 Yield distribution mechanisms
- 🔄 Governance token integration
- 🔄 Advanced reputation algorithms
- 🔄 Cross-chain compatibility

### Phase 3 (Future)
- 🔄 Mobile app integration
- 🔄 Automated strategy vaults
- 🔄 Insurance mechanisms
- 🔄 Community governance

## 🤝 Contributing

We welcome contributions! Please see our contributing guidelines:

1. Fork the repository
2. Create a feature branch
3. Write comprehensive tests
4. Submit a pull request with detailed description