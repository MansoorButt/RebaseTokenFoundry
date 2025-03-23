# RebaseToken: Cross-Chain Yield Optimization Protocol



## Overview

RebaseToken is an advanced cross-chain DeFi yield optimization protocol that enables users to deposit ETH into a vault and earn interest that automatically compounds through a rebasing token mechanism. The protocol leverages Chainlink CCIP (Cross-Chain Interoperability Protocol) to enable seamless token transfers between Ethereum Sepolia and Arbitrum Sepolia networks.

## Key Features

- **Automated Yield Accrual**: Interest automatically compounds based on a dynamically adjustable global interest rate
- **Per-User Interest Rates**: Each user's interest rate is set at the time of minting, providing predictable returns
- **Cross-Chain Functionality**: Transfer tokens between Ethereum and Arbitrum while preserving accrued interest
- **Time-Based Interest Model**: Interest calculations based on elapsed time since last update
- **Flexible Vault System**: Secure deposit and redemption mechanism with 1:1 ETH backing

## Technical Architecture

### Core Components

1. **RebaseToken Contract**: ERC20-compatible token that implements the rebasing mechanism
   - Maintains per-user interest rates
   - Implements time-based interest accrual
   - Automatic calculation of accrued interest during transfers
   - Role-based access control for minting and burning

2. **Vault Contract**: Manages deposits and redemptions
   - Accepts ETH deposits and mints equivalent RebaseTokens (RWT)
   - Handles redemptions of RWT back to ETH
   - Acts as a secure custody solution for user funds

3. **RebaseTokenPool**: Handles cross-chain token transfers
   - Leverages Chainlink CCIP for secure cross-chain messaging
   - Manages rate limiting configurations for both inbound and outbound transfers
   - Preserves user-specific interest rates during cross-chain transfers

### Cross-Chain Implementation

The project implements a sophisticated cross-chain architecture using Chainlink CCIP:

- **Chain Coordination**: Both chains are configured to recognize each other's token contracts and pool addresses
- **Message Passing**: Custom encoded messages for cross-chain token transfers
- **Rate Limiting**: Configurable rate limiters to prevent economic attacks
- **Pool Registry**: TokenAdminRegistry system for managing cross-chain pool relationships
- **Ownership Management**: Custom registry module owner for managing admin privileges

## Advanced Technical Features

### Network Forking

The test suite utilizes Foundry's forking capabilities to simulate interactions between Ethereum Sepolia and Arbitrum Sepolia:

```solidity
sepoliaFork = vm.createSelectFork("sepolia-eth");
arbSepoliaFork = vm.createFork("arb-sepolia");
```

This allows for realistic testing of cross-chain interactions without deploying to actual testnets.

### CCIP Local Simulation

A local CCIP simulator is implemented for testing cross-chain message passing:

```solidity
ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
vm.makePersistent(address(ccipLocalSimulatorFork));
```

The simulator facilitates:
- Cross-chain message routing
- Fork switching to simulate different blockchain environments
- Fee estimation and payment handling

### Time Manipulation

Time-warping is utilized to test interest accrual over simulated time periods:

```solidity
vm.warp(block.timestamp + 3600); // Advance time by 1 hour
```

This enables verification of the rebasing mechanism and interest calculations over various time horizons.

### Dynamic Interest Rate Model

The protocol features a dynamic interest rate model:

```solidity
linearInterest = PRECISION_FACTOR + (timeElapsed * userInterestRate[_user] * PRECISION_FACTOR / (365 days));
```

This calculation provides:
- Pro-rata daily interest accrual
- High precision calculations using 18 decimal places
- User-specific interest tracking

### Bridge Automation

The deployment scripts include automated bridging between networks:

```bash
# Configure the pool on Sepolia to connect with Arbitrum Sepolia
forge script ./script/ConfigurePool.s.sol:ConfigurePoolScript --rpc-url ${SEPOLIA_RPC_URL} --account updraft --broadcast
```

The `bridgeToArb.sh` script automates:
- Contract deployment on both chains
- Pool configuration and permission setup
- Initial token minting and funding
- Cross-chain token transfers

## Technical Innovations

### Persistent Interest Rates Across Chains

One of the most innovative aspects of this protocol is how it preserves user-specific interest rates during cross-chain transfers, ensuring that users receive consistent yield regardless of which chain their tokens reside on.

### Enhanced Balance Calculation

The contract overrides the standard `balanceOf` function to incorporate accrued interest:

```solidity
function balanceOf(address account) public view override returns (uint256) {
    uint256 balance = super.balanceOf(account);
    return balance * calculateAccruedInterest(account) / PRECISION_FACTOR;
}
```

This allows for real-time interest reflection in user balances without requiring transactions.

### Automated Interest Accrual

The protocol implements automated interest accrual during any token transfer or operation:

```solidity
function _mintAccruedInterest(address _user) internal {
    uint256 principleBalance = super.balanceOf(_user);
    uint256 currentBalance = balanceOf(_user);
    uint256 balanceIncreased = currentBalance - principleBalance;

    last_Updated[_user] = block.timestamp;
    _mint(_user, balanceIncreased);
}
```

This ensures that interest is always properly calculated and credited before any token movement.

## Testing Suite

The protocol includes comprehensive tests verifying:

- Cross-chain token bridging integrity
- Interest accrual mechanics 
- Multiple bridging scenarios
- Time-based yield calculations
- Balance preservation across chains

Example test:

```solidity
function testBridgeAllTokensBack() public {
    // Configure pools on both chains
    configureTokenPool(...);
    
    // Setup initial conditions
    vm.selectFork(sepoliaFork);
    vm.deal(alice, SEND_VALUE);
    
    // Deposit ETH and receive tokens
    Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
    
    // Bridge tokens to destination chain
    bridgeTokens(...);
    
    // Time passes on destination chain
    vm.selectFork(arbSepoliaFork);
    vm.warp(block.timestamp + 3600);
    
    // Bridge back to source chain
    uint256 destBalance = destRebaseToken.balanceOf(alice);
    bridgeTokens(...);
}
```

## Deployment

The protocol can be deployed using the included scripts:

```bash
# Install dependencies
forge install

# Deploy contracts
./bridgeToArb.sh
```

This will deploy the entire protocol infrastructure across both Ethereum Sepolia and Arbitrum Sepolia testnets.

## Future Enhancements

- Governance mechanism for protocol parameters
- Multi-collateral vault options
- Leveraged positions with cross-chain liquidity
- Integration with additional L2 networks
- Optimization for gas efficiency in cross-chain transfers

## License

This project is licensed under the MIT License - see the LICENSE file for details.
