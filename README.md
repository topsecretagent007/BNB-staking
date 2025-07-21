# DRIP BNB LP Staking

## Overview
This project implements a DeFi staking system on BNB Chain, featuring a DRIP token with inflationary minting, a staking contract for LP tokens, a treasury for tax and reward management, and a vault for secure token storage.

## Main Contracts
- **DripToken**: Mintable BEP20 token with customizable inflation, transfer taxes, and whitelisting.
- **DRIP_BNBLPToken**: BEP20 LP token for staking.
- **DripStaking**: Users stake LP tokens for rewards, with lock periods (1–52 weeks) and boost multipliers.
- **Treasury**: Receives taxes, burns 90%, sends 10% to treasury, and distributes 1% daily to staking rewards.
- **Vault**: Holds DRIP tokens, only whitelisted addresses can withdraw.

## Key Features
- Adjustable DRIP inflation rate.
- Staking with lock periods (up to 52 weeks) and reward boosts.
- Automated tax handling: 90% burn, 10% to treasury.
- Daily reward distribution from treasury to stakers.
- Full test suite for deployment, staking, claiming, and withdrawal.

## Installation
```sh
npm install
```

## Compilation
```sh
npx hardhat compile
```

## Testing
```sh
npx hardhat test
```

## Deployment
1. Set your private key in `hardhat.config.js`:
   ```js
   const PRIVATE_KEY = "your_private_key";
   ```
2. Deploy contracts:
   ```sh
   npx hardhat run scripts/deploy.js --network <network-name>
   ```
   - Supported networks: `bsctest`, `bsc`, `bbfork`, or `hardhat` (local).

Deployment outputs contract addresses to `contracts.env`.

## Environment
- Uses Hardhat, OpenZeppelin, and hardhat-faucet.
- All contract addresses are saved in `contracts.env` after deployment.

## Testing Coverage
- Contract deployment and initialization.
- Staking and lock period logic.
- Reward calculation and claiming.
- Tax and treasury payout logic.
- Vault withdrawal and access control.

## Customization
- Inflation rate, payout rate, and cooldowns are owner-configurable.
- Treasury and vault addresses can be updated post-deployment.

---
For more details, see the contract files in the `contracts/` directory and the test suite in `test/test.js`.
