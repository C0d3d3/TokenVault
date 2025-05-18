# TokenVault

A decentralized token staking and rewards platform where users can stake their tokens in various yield-generating strategies.

## Overview

TokenVault is a Clarity smart contract that enables a decentralized staking ecosystem on the Stacks blockchain. It allows users to stake their tokens in different yield-generating pools and earn rewards based on their chosen strategies, all while maintaining full control of their assets.

## Features

- **Strategy Selection**: Users choose which yield strategies they want to participate in
- **Direct Rewards**: Users receive STX tokens directly for staking in pools
- **No Intermediaries**: Pool creators connect directly with stakers
- **Transparent Fee Structure**: Small protocol fee to sustain the ecosystem
- **Pool Management**: Creators can create, pause, and manage yield pools

## Contract Functions

### User Functions

- `register-staker`: Register as a new staker with strategy preferences
- `update-strategies`: Update your yield strategy preferences
- `pause-staking`: Temporarily pause your staking activities
- `resume-staking`: Re-enable staking after pausing
- `stake-in-pool`: Stake in a yield pool and receive rewards
- `claim-rewards`: Withdraw your earned STX tokens

### Pool Creator Functions

- `create-yield-pool`: Create a new yield-generating pool
- `pause-pool`: Temporarily pause an active pool
- `resume-pool`: Resume a paused pool
- `add-pool-liquidity`: Add more liquidity to an existing pool

### Admin Functions

- `set-contract-owner`: Update the contract administrator
- `set-protocol-fee`: Adjust the protocol fee percentage
- `add-strategy`: Add a new yield strategy type
- `withdraw-protocol-fees`: Withdraw accumulated protocol fees

### Read-Only Functions

- `get-staker-profile`: View a staker's profile and preferences
- `get-pool`: Get details about a yield pool
- `get-strategy`: Get information about a yield strategy
- `get-protocol-fee`: Check the current protocol fee percentage
- `get-protocol-balance`: View the accumulated protocol fees
- `get-stake-record`: Check if a user has staked in a specific pool

## How It Works

1. **For Stakers**:
   - Register with your strategy preferences
   - Stake in pools that match your preferences
   - Automatically receive STX tokens as rewards
   - Claim your rewards anytime

2. **For Pool Creators**:
   - Create pools with liquidity and a reward rate
   - Target specific strategy types
   - Attract stakers to your pools
   - Manage pools with pause/resume functionality

## Security Features

- Users only stake in pools matching their stated preferences
- No locking periods - users maintain control of their assets
- Users can opt-out at any time
- All interactions are pseudonymous via blockchain addresses

## Development

This contract is developed using Clarity and can be tested with Clarinet.