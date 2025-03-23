#!/bin/bash

# Define constants 
AMOUNT=100000

# Ethereum Sepolia addresses
SEPOLIA_REGISTRY_MODULE_OWNER_CUSTOM="0x62e731218d0D47305aba2BE3751E7EE9E5520790"
SEPOLIA_TOKEN_ADMIN_REGISTRY="0x95F29FEE11c5C55d26cCcf1DB6772DE953B37B82"
SEPOLIA_ROUTER="0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59"
SEPOLIA_RNM_PROXY_ADDRESS="0xba3f6251de62dED61Ff98590cB2fDf6871FbB991"
SEPOLIA_CHAIN_SELECTOR="16015286601757825753"
SEPOLIA_LINK_ADDRESS="0x779877A7B0D9E8603169DdbD7836e478b4624789"

# Arbitrum Sepolia addresses
ARBITRUM_SEPOLIA_CHAIN_SELECTOR="3478487238524512106"  # Arbitrum Sepolia chain selector
ARBITRUM_REGISTRY_MODULE_OWNER_CUSTOM="0xE625f0b8b0Ac86946035a7729Aba124c8A64cf69"
ARBITRUM_TOKEN_ADMIN_REGISTRY="0x8126bE56454B628a88C17849B9ED99dd5a11Bd2f"
ARBITRUM_ROUTER="0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165"
ARBITRUM_RNM_PROXY_ADDRESS="0x9527E2d01A3064ef6b50c1Da1C0cC523803BCFF2"
ARBITRUM_LINK_ADDRESS="0xb1D4538B4571d411F07960EF2838Ce337FE1E80E"

source .env

# Check if environment variables are set
if [ -z "${SEPOLIA_RPC_URL}" ]; then
    echo "SEPOLIA_RPC_URL not set in .env file"
    exit 1
fi

if [ -z "${ARBITRUM_SEPOLIA_RPC_URL}" ]; then
    echo "ARBITRUM_SEPOLIA_RPC_URL not set in .env file"
    exit 1
fi

# Compile contracts
echo "Compiling contracts..."
forge build

#############################
# 1. Deploy on Arbitrum Sepolia
#############################

echo "Deploying the Rebase Token contract on Arbitrum Sepolia..."
DEPLOY_OUTPUT=$(forge create src/RebaseToken.sol:RebaseToken --rpc-url ${ARBITRUM_SEPOLIA_RPC_URL} --account updraft --legacy --broadcast)
echo "$DEPLOY_OUTPUT"
ARBITRUM_REBASE_TOKEN_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oP 'Deployed to: \K0x[0-9a-fA-F]+')

# Check if we got a valid address
if [[ ! "$ARBITRUM_REBASE_TOKEN_ADDRESS" =~ ^0x[0-9a-fA-F]+$ ]]; then
    echo "Failed to get a valid contract address. Deployment output: $DEPLOY_OUTPUT"
    exit 1
fi

echo "Arbitrum Sepolia rebase token address: $ARBITRUM_REBASE_TOKEN_ADDRESS"

# Deploy the pool contract on Arbitrum Sepolia
echo "Deploying the pool contract on Arbitrum Sepolia..."
EMPTY_ARRAY="[]"
ARBITRUM_POOL_OUTPUT=$(forge create src/RebaseTokenPool.sol:RebaseTokenPool --rpc-url ${ARBITRUM_SEPOLIA_RPC_URL} --account updraft --legacy --broadcast --constructor-args ${ARBITRUM_REBASE_TOKEN_ADDRESS} "${EMPTY_ARRAY}" ${ARBITRUM_RNM_PROXY_ADDRESS} ${ARBITRUM_ROUTER})
echo "$ARBITRUM_POOL_OUTPUT"
ARBITRUM_POOL_ADDRESS=$(echo "$ARBITRUM_POOL_OUTPUT" | grep -oP 'Deployed to: \K0x[0-9a-fA-F]+')
echo "Arbitrum Sepolia pool address: $ARBITRUM_POOL_ADDRESS"

# Check if deployment was successful
if [ -z "$ARBITRUM_POOL_ADDRESS" ]; then
    echo "Failed to deploy Pool on Arbitrum Sepolia"
    exit 1
fi

# Set the permissions for the pool contract on Arbitrum Sepolia
echo "Setting the permissions for the pool contract on Arbitrum Sepolia..."
cast send ${ARBITRUM_REBASE_TOKEN_ADDRESS} "grantMintandBurnRole(address)" ${ARBITRUM_POOL_ADDRESS} --rpc-url ${ARBITRUM_SEPOLIA_RPC_URL} --account updraft
echo "Pool permissions set on Arbitrum Sepolia"

# Set the CCIP roles and permissions on Arbitrum Sepolia
echo "Setting the CCIP roles and permissions on Arbitrum Sepolia..."
cast send ${ARBITRUM_REGISTRY_MODULE_OWNER_CUSTOM} "registerAdminViaOwner(address)" ${ARBITRUM_REBASE_TOKEN_ADDRESS} --rpc-url ${ARBITRUM_SEPOLIA_RPC_URL} --account updraft
cast send ${ARBITRUM_TOKEN_ADMIN_REGISTRY} "acceptAdminRole(address)" ${ARBITRUM_REBASE_TOKEN_ADDRESS} --rpc-url ${ARBITRUM_SEPOLIA_RPC_URL} --account updraft
cast send ${ARBITRUM_TOKEN_ADMIN_REGISTRY} "setPool(address,address)" ${ARBITRUM_REBASE_TOKEN_ADDRESS} ${ARBITRUM_POOL_ADDRESS} --rpc-url ${ARBITRUM_SEPOLIA_RPC_URL} --account updraft
echo "CCIP roles and permissions set on Arbitrum Sepolia"

#############################
# 2. Deploy on Ethereum Sepolia
#############################

echo "Running the script to deploy the contracts on Ethereum Sepolia..."
SEPOLIA_DEPLOYMENT=$(forge script ./script/Deployer.s.sol:TokenAndPoolDeployer --rpc-url ${SEPOLIA_RPC_URL} --account updraft --broadcast)
echo "$SEPOLIA_DEPLOYMENT"

# Extract the addresses from the output
SEPOLIA_REBASE_TOKEN_ADDRESS=$(echo "$SEPOLIA_DEPLOYMENT" | grep -oP 'token: contract RebaseToken\s*\K0x[0-9a-fA-F]+')
SEPOLIA_POOL_ADDRESS=$(echo "$SEPOLIA_DEPLOYMENT" | grep -oP 'pool: contract RebaseTokenPool\s*\K0x[0-9a-fA-F]+')

if [ -z "$SEPOLIA_REBASE_TOKEN_ADDRESS" ] || [ -z "$SEPOLIA_POOL_ADDRESS" ]; then
    echo "Failed to extract Sepolia addresses. Trying alternative extraction method..."
    SEPOLIA_REBASE_TOKEN_ADDRESS=$(echo "$SEPOLIA_DEPLOYMENT" | grep -A1 'token:' | tail -n1 | tr -d '[:space:]')
    SEPOLIA_POOL_ADDRESS=$(echo "$SEPOLIA_DEPLOYMENT" | grep -A1 'pool:' | tail -n1 | tr -d '[:space:]')
    
    if [ -z "$SEPOLIA_REBASE_TOKEN_ADDRESS" ] || [ -z "$SEPOLIA_POOL_ADDRESS" ]; then
        echo "Failed to extract Sepolia addresses. Check the deployment output above."
        exit 1
    fi
fi

echo "Sepolia rebase token address: $SEPOLIA_REBASE_TOKEN_ADDRESS"
echo "Sepolia pool address: $SEPOLIA_POOL_ADDRESS"

# Deploy the vault on Sepolia
echo "Deploying the vault on Sepolia..."
VAULT_DEPLOYMENT=$(forge script ./script/Deployer.s.sol:VaultDeployer --rpc-url ${SEPOLIA_RPC_URL} --account updraft --broadcast --sig "run(address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS})
echo "$VAULT_DEPLOYMENT"
VAULT_ADDRESS=$(echo "$VAULT_DEPLOYMENT" | grep -oP 'vault: contract Vault\s*\K0x[0-9a-fA-F]+')

if [ -z "$VAULT_ADDRESS" ]; then
    echo "Failed to extract vault address. Trying alternative extraction method..."
    VAULT_ADDRESS=$(echo "$VAULT_DEPLOYMENT" | grep -A1 'vault:' | tail -n1 | tr -d '[:space:]')
    
    if [ -z "$VAULT_ADDRESS" ]; then
        echo "Failed to extract vault address. Check the deployment output above."
        exit 1
    fi
fi

echo "Vault address: $VAULT_ADDRESS"

# Configure the pool on Sepolia to connect with Arbitrum Sepolia
echo "Configuring the pool on Sepolia..."
forge script ./script/ConfigurePool.s.sol:ConfigurePoolScript --rpc-url ${SEPOLIA_RPC_URL} --account updraft --broadcast --sig "run(address,uint64,address,address,bool,uint128,uint128,bool,uint128,uint128)" ${SEPOLIA_POOL_ADDRESS} ${ARBITRUM_SEPOLIA_CHAIN_SELECTOR} ${ARBITRUM_POOL_ADDRESS} ${ARBITRUM_REBASE_TOKEN_ADDRESS} false 0 0 false 0 0

# Deposit funds to the vault
echo "Depositing funds to the vault on Sepolia..."
cast send ${VAULT_ADDRESS} --value ${AMOUNT} --rpc-url ${SEPOLIA_RPC_URL} --account updraft "deposit()"
echo "Funds deposited to the vault on Sepolia"

# Configure the pool on Arbitrum Sepolia to connect with Ethereum Sepolia
echo "Configuring the pool on Arbitrum Sepolia..."
POOL_ADDRESS_DATA=$(cast abi-encode "a(address)" ${SEPOLIA_POOL_ADDRESS})
TOKEN_ADDRESS_DATA=$(cast abi-encode "a(address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS})
cast send ${ARBITRUM_POOL_ADDRESS} --rpc-url ${ARBITRUM_SEPOLIA_RPC_URL} --account updraft "applyChainUpdates((uint64,bool,bytes,bytes,(bool,uint128,uint128),(bool,uint128,uint128))[])" "[(${SEPOLIA_CHAIN_SELECTOR},true,${POOL_ADDRESS_DATA},${TOKEN_ADDRESS_DATA},(false,0,0),(false,0,0))]"
echo "Pool configured on Arbitrum Sepolia"

# Bridge tokens from Sepolia to Arbitrum Sepolia
echo "Bridging tokens from Sepolia to Arbitrum Sepolia..."
SEPOLIA_BALANCE_BEFORE=$(cast call ${SEPOLIA_REBASE_TOKEN_ADDRESS} "balanceOf(address)(uint256)" $(cast wallet address --account updraft) --rpc-url ${SEPOLIA_RPC_URL})
echo "Sepolia balance before bridging: $SEPOLIA_BALANCE_BEFORE"

# Approve tokens for CCIP router
cast send ${SEPOLIA_REBASE_TOKEN_ADDRESS} "approve(address,uint256)" ${SEPOLIA_ROUTER} ${AMOUNT} --rpc-url ${SEPOLIA_RPC_URL} --account updraft
echo "Tokens approved for CCIP router"

# Approve LINK for fees
cast send ${SEPOLIA_LINK_ADDRESS} "approve(address,uint256)" ${SEPOLIA_ROUTER} 1000000000000000000 --rpc-url ${SEPOLIA_RPC_URL} --account updraft
echo "LINK approved for fees"

# Bridge tokens using the BridgeTokens script
forge script ./script/BridgeTokens.s.sol:BridgeTokensScript --rpc-url ${SEPOLIA_RPC_URL} --account updraft --broadcast --sig "run(address,uint64,address,uint256,address,address)" $(cast wallet address --account updraft) ${ARBITRUM_SEPOLIA_CHAIN_SELECTOR} ${SEPOLIA_REBASE_TOKEN_ADDRESS} ${AMOUNT} ${SEPOLIA_LINK_ADDRESS} ${SEPOLIA_ROUTER}
echo "Funds bridged to Arbitrum Sepolia"

# Check balance after bridging
SEPOLIA_BALANCE_AFTER=$(cast call ${SEPOLIA_REBASE_TOKEN_ADDRESS} "balanceOf(address)(uint256)" $(cast wallet address --account updraft) --rpc-url ${SEPOLIA_RPC_URL})
echo "Sepolia balance after bridging: $SEPOLIA_BALANCE_AFTER"

echo "Script completed successfully"