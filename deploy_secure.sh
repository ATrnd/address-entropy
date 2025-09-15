#!/bin/bash
# Secure Deployment Script for AddressDataEntropy
# Uses Forge's encrypted keystore system

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
KEYSTORE_NAME=${1:-"testnet-deployer"}
NETWORK=${2:-"sepolia"}
SCRIPT=${3:-"script/TestnetDeploy.s.sol"}

# Load environment variables if .env exists
if [ -f .env ]; then
    set -a  # automatically export all variables
    source .env
    set +a  # disable automatic export
fi

echo -e "${BLUE}🔐 Secure Deployment Script${NC}"
echo -e "${BLUE}=============================${NC}"
echo ""

# Network RPC URL mapping
case $NETWORK in
    "sepolia")
        RPC_URL=${SEPOLIA_RPC_URL:-"https://sepolia.infura.io/v3/YOUR_PROJECT_ID"}
        EXPLORER="https://sepolia.etherscan.io"
        CHAIN_ID="11155111"
        ;;
    "goerli")
        RPC_URL=${GOERLI_RPC_URL:-"https://goerli.infura.io/v3/YOUR_PROJECT_ID"}
        EXPLORER="https://goerli.etherscan.io"
        CHAIN_ID="5"
        ;;
    "shape")
        RPC_URL=${SHAPE_MAINNET_RPC_URL:-"https://mainnet.shape.network"}
        EXPLORER="https://shapescan.xyz"
        CHAIN_ID="360"
        ;;
    "mumbai")
        RPC_URL=${MUMBAI_RPC_URL:-"https://polygon-mumbai.g.alchemy.com/v2/YOUR_API_KEY"}
        EXPLORER="https://mumbai.polygonscan.com"
        CHAIN_ID="80001"
        ;;
    *)
        echo -e "${RED}❌ Unknown network: $NETWORK${NC}"
        echo -e "${YELLOW}Available networks:${NC}"
        echo "  - sepolia    (Ethereum testnet)"
        echo "  - goerli     (Ethereum testnet - legacy)"
        echo "  - shape      (Shape Mainnet - L2 for creators)"
        echo "  - mumbai     (Polygon testnet)"
        echo ""
        echo -e "${BLUE}Usage: $0 [keystore] [network] [script]${NC}"
        echo "Example: $0 testnet-deployer shape"
        exit 1
        ;;
esac

echo -e "${BLUE}🔐 Keystore:${NC} $KEYSTORE_NAME"
echo -e "${BLUE}🌐 Network:${NC} $NETWORK (Chain ID: $CHAIN_ID)"
echo -e "${BLUE}🔗 RPC URL:${NC} $RPC_URL"
echo -e "${BLUE}🔍 SEPOLIA_RPC_URL from env:${NC} $SEPOLIA_RPC_URL"
echo -e "${BLUE}📜 Script:${NC} $SCRIPT"
echo ""

# Verify RPC URL is set
if [[ "$RPC_URL" == *"YOUR_PROJECT_ID"* ]] || [[ "$RPC_URL" == *"YOUR_API_KEY"* ]]; then
    echo -e "${RED}❌ RPC URL not configured!${NC}"
    echo -e "${YELLOW}Please set up your .env file with proper RPC URLs${NC}"
    echo ""
    echo "Example .env setup:"
    echo "SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/your_project_id"
    echo "SHAPE_MAINNET_RPC_URL=https://mainnet.shape.network"
    echo "MUMBAI_RPC_URL=https://polygon-mumbai.g.alchemy.com/v2/your_api_key"
    exit 1
fi

# Verify keystore exists
echo -e "${YELLOW}🔍 Checking keystore...${NC}"
if ! cast wallet list | grep -q "$KEYSTORE_NAME"; then
    echo -e "${RED}❌ Keystore '$KEYSTORE_NAME' not found!${NC}"
    echo ""
    echo -e "${YELLOW}Available keystores:${NC}"
    cast wallet list || echo "No keystores found"
    echo ""
    echo -e "${BLUE}To create a new keystore:${NC}"
    echo "cast wallet import $KEYSTORE_NAME --interactive"
    exit 1
fi

# Get address and check balance
echo -e "${YELLOW}💰 Checking balance...${NC}"
ADDRESS=$(cast wallet address --account $KEYSTORE_NAME)
echo -e "${BLUE}📍 Address:${NC} $ADDRESS"

# Skip balance check for now (can be flaky with some RPC endpoints)
echo "Skipping balance check to avoid RPC timeout issues"
echo -e "${BLUE}💰 Balance:${NC} Assuming sufficient (skipped check)"
echo ""
echo -e "${YELLOW}⚠️  Note: Balance check skipped due to RPC timeout${NC}"
echo -e "${YELLOW}   Make sure your account has sufficient ETH before proceeding${NC}"
echo ""
read -p "Continue with deployment? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 1
fi

# Pre-deployment summary
echo ""
echo -e "${GREEN}✅ Pre-deployment checks passed${NC}"
echo -e "${BLUE}📋 Deployment Summary:${NC}"
echo "   Deployer: $ADDRESS"
echo "   Network: $NETWORK ($CHAIN_ID)"
echo "   Explorer: $EXPLORER"
echo "   Balance: $BALANCE_ETH ETH"
echo ""

# Final confirmation
read -p "🚀 Proceed with deployment? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 1
fi

# Deploy
echo ""
echo -e "${GREEN}🚀 Starting deployment...${NC}"
echo -e "${BLUE}=================================${NC}"

# Create deployment log
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="deployments/${NETWORK}_${TIMESTAMP}.log"
mkdir -p deployments

# Run deployment with logging
forge script $SCRIPT \
    --account $KEYSTORE_NAME \
    --rpc-url $RPC_URL \
    --broadcast \
    --force 2>&1 | tee $LOG_FILE

DEPLOYMENT_STATUS=$?

echo ""
if [ $DEPLOYMENT_STATUS -eq 0 ]; then
    echo -e "${GREEN}✅ Deployment completed successfully!${NC}"

    # Extract contract address from logs (if available)
    CONTRACT_ADDRESS=$(grep -o "Contract Address: 0x[a-fA-F0-9]\{40\}" $LOG_FILE | tail -1 | cut -d' ' -f3 || echo "Not found in logs")

    if [ "$CONTRACT_ADDRESS" != "Not found in logs" ]; then
        echo -e "${BLUE}📍 Contract Address:${NC} $CONTRACT_ADDRESS"
        echo -e "${BLUE}🔍 Explorer:${NC} $EXPLORER/address/$CONTRACT_ADDRESS"

        # Save deployment info
        echo "Deployment completed: $(date)" >> deployments/DEPLOYMENTS.log
        echo "Network: $NETWORK" >> deployments/DEPLOYMENTS.log
        echo "Address: $CONTRACT_ADDRESS" >> deployments/DEPLOYMENTS.log
        echo "Deployer: $ADDRESS" >> deployments/DEPLOYMENTS.log
        echo "Log: $LOG_FILE" >> deployments/DEPLOYMENTS.log
        echo "---" >> deployments/DEPLOYMENTS.log
    fi

    echo ""
    echo -e "${GREEN}🎉 Next steps:${NC}"
    echo "1. Verify contract on explorer: $EXPLORER"
    echo "2. Test basic functionality"
    echo "3. Document deployment in your project"
    echo "4. Monitor contract performance"

    if [ "$NETWORK" = "shape" ]; then
        echo ""
        echo -e "${BLUE}💰 Shape Mainnet Benefits:${NC}"
        echo "- You'll earn 80% of gas fees from contract usage"
        echo "- Monitor creator rewards on Shape dashboard"
        echo "- Consider building more contracts for additional revenue"
    fi

else
    echo -e "${RED}❌ Deployment failed!${NC}"
    echo -e "${YELLOW}Check the log file for details: $LOG_FILE${NC}"
    echo ""
    echo -e "${BLUE}Common issues:${NC}"
    echo "- Insufficient balance for gas fees"
    echo "- Network connectivity issues"
    echo "- Contract compilation errors"
    echo "- Invalid constructor parameters"
    exit 1
fi

echo ""
echo -e "${BLUE}📝 Log saved to: $LOG_FILE${NC}"
echo -e "${GREEN}Deployment process complete!${NC}"
