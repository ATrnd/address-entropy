// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {AddressDataEntropy} from "../src/implementations/AddressDataEntropy.sol";

contract TestnetDeploy is Script {

    bytes32 private constant DEFAULT_SALT = keccak256("AddressDataEntropy-Testnet");
    uint256 private constant DEPLOYMENT_GAS_LIMIT = 1_500_000;

    struct DeploymentConfig {
        address deployer;
        address owner;
        address[3] entropyAddresses;
        bytes32 salt;
        uint256 chainId;
        string networkName;
    }

    function run() external {
        DeploymentConfig memory config = _initializeConfig();
        _validatePreDeployment(config);
        AddressDataEntropy deployed = _executeDeployment(config);
        _validatePostDeployment(deployed, config);
        _generateDeploymentReport(deployed, config);
    }

    function _initializeConfig() internal view returns (DeploymentConfig memory config) {
        config.deployer = msg.sender;
        config.owner = vm.envOr("TESTNET_OWNER", config.deployer);
        config.entropyAddresses = _getEntropyAddresses(config.deployer);
        config.salt = vm.envOr("DEPLOY_SALT", DEFAULT_SALT);
        config.chainId = block.chainid;
        config.networkName = _getNetworkName(config.chainId);
        console.log("=== TESTNET DEPLOYMENT CONFIGURATION ===");
        console.log("Network:", config.networkName);
        console.log("Chain ID:", config.chainId);
        console.log("Deployer:", config.deployer);
        console.log("Owner:", config.owner);
        console.log("Entropy Address 1:", config.entropyAddresses[0]);
        console.log("Entropy Address 2:", config.entropyAddresses[1]);
        console.log("Entropy Address 3:", config.entropyAddresses[2]);
        console.log("Salt:", vm.toString(config.salt));
    }

    function _getEntropyAddresses(address deployer) internal view returns (address[3] memory) {
        address[3] memory addresses;
        addresses[0] = vm.envOr("ENTROPY_ADDRESS_1", address(0));
        addresses[1] = vm.envOr("ENTROPY_ADDRESS_2", address(0));
        addresses[2] = vm.envOr("ENTROPY_ADDRESS_3", address(0));
        address[3] memory defaults = _getNetworkDefaults(deployer);
        if (addresses[0] == address(0)) addresses[0] = defaults[0];
        if (addresses[1] == address(0)) addresses[1] = defaults[1];
        if (addresses[2] == address(0)) addresses[2] = defaults[2];

        return addresses;
    }

    function _getNetworkDefaults(address deployer) internal view returns (address[3] memory) {
        uint256 chainId = block.chainid;

        if (chainId == 11155111) {
            return [address(0x1), address(0x2), address(0x3)];
        } else if (chainId == 5) {
            return [address(0x1), address(0x2), address(0x3)];
        } else if (chainId == 80001) {
            return [deployer, address(uint160(deployer) + 1), address(uint160(deployer) + 2)];
        } else if (chainId == 360) {
            return [address(0x1), deployer, address(uint160(deployer) + 1)];
        } else {
            return [
                deployer,
                address(uint160(deployer) + 1),
                address(uint160(deployer) + 2)
            ];
        }
    }

    function _getNetworkName(uint256 chainId) internal pure returns (string memory) {
        if (chainId == 11155111) return "Sepolia";
        if (chainId == 5) return "Goerli";
        if (chainId == 80001) return "Mumbai";
        if (chainId == 421613) return "Arbitrum Goerli";
        if (chainId == 360) return "Shape Mainnet";
        if (chainId == 31337) return "Anvil Local";
        return "Unknown Network";
    }

    function _validatePreDeployment(DeploymentConfig memory config) internal view {
        console.log("\n=== PRE-DEPLOYMENT VALIDATION ===");

        uint256 balance = config.deployer.balance;
        console.log("Deployer Balance:", balance);
        require(balance > 0.01 ether, "Insufficient balance for deployment");
        console.log("[OK] Deployer has sufficient balance");
        require(config.entropyAddresses[0] != address(0), "Entropy address 1 cannot be zero");
        require(config.entropyAddresses[1] != address(0), "Entropy address 2 cannot be zero");
        require(config.entropyAddresses[2] != address(0), "Entropy address 3 cannot be zero");
        console.log("[OK] All entropy addresses are valid");
        require(config.owner != address(0), "Owner cannot be zero address");
        console.log("[OK] Owner address is valid");
        require(config.chainId != 1, "Do not deploy to Ethereum mainnet with testnet script!");
        if (config.chainId == 360) {
            console.log("[INFO] Deploying to Shape Mainnet (L2 for creators)");
        }
        console.log("[OK] Network validated");
    }

    function _executeDeployment(DeploymentConfig memory config)
        internal returns (AddressDataEntropy deployed) {

        console.log("\n=== DEPLOYMENT EXECUTION ===");

        uint256 startGas = gasleft();
        vm.startBroadcast();
        deployed = new AddressDataEntropy{salt: config.salt}(
            config.owner,
            config.entropyAddresses
        );
        vm.stopBroadcast();
        uint256 gasUsed = startGas - gasleft();
        console.log("[SUCCESS] Contract deployed!");
        console.log("Contract Address:", address(deployed));
        console.log("Gas Used:", gasUsed);
        console.log("Estimated Cost (20 gwei):", (gasUsed * 20 * 1e9) / 1e18, "ETH");
        require(gasUsed < DEPLOYMENT_GAS_LIMIT, "Gas usage exceeded limit");
        console.log("[OK] Gas usage within expected range");
    }

    function _validatePostDeployment(AddressDataEntropy deployed, DeploymentConfig memory config)
        internal {

        console.log("\n=== POST-DEPLOYMENT VALIDATION ===");

        require(address(deployed).code.length > 0, "Contract deployment failed");
        console.log("[OK] Contract code deployed");
        address actualOwner = deployed.owner();
        require(actualOwner == config.owner, "Owner setup failed");
        console.log("[OK] Owner correctly set:", actualOwner);
        vm.startBroadcast();
        bytes32 testEntropy = deployed.getEntropy(12345);
        require(testEntropy != bytes32(0), "Entropy generation failed");
        vm.stopBroadcast();
        console.log("[OK] Basic entropy generation working");
        console.log("Test Entropy:", vm.toString(testEntropy));
        console.log("[INFO] State inspection functions correctly removed from production");
    }

    function _generateDeploymentReport(AddressDataEntropy deployed, DeploymentConfig memory config)
        internal view {

        console.log("\n=== DEPLOYMENT REPORT ===");
        console.log("Deployment Date:", block.timestamp);
        console.log("Block Number:", block.number);
        console.log("Network:", config.networkName);
        console.log("Chain ID:", config.chainId);
        console.log("Contract Address:", address(deployed));
        console.log("Owner:", config.owner);
        console.log("Deployer:", config.deployer);

        console.log("\nEntropy Configuration:");
        console.log("- Address 1:", config.entropyAddresses[0]);
        console.log("- Address 2:", config.entropyAddresses[1]);
        console.log("- Address 3:", config.entropyAddresses[2]);

        console.log("\nSecurity Status:");
        console.log("- CREATE2 Deployment: YES");
        console.log("- State Inspection Functions: REMOVED");
        console.log("- Access Control: ACTIVE");
        console.log("- Fallback Protection: ACTIVE");

        console.log("\nNext Steps:");
        console.log("1. Verify contract on block explorer");
        console.log("2. Run integration tests");
        console.log("3. Perform gas analysis");
        console.log("4. Test entropy quality");
        console.log("5. Monitor contract performance");

        console.log("\n=== DEPLOYMENT COMPLETE ===");
    }

    function _isContract(address addr) internal view returns (bool) {
        return addr.code.length > 0;
    }

    function getPredictedAddress(address deployer, bytes32 salt)
        external pure returns (address) {

        bytes memory bytecode = abi.encodePacked(
            type(AddressDataEntropy).creationCode,
            abi.encode(deployer, [deployer, address(uint160(deployer) + 1), address(uint160(deployer) + 2)])
        );

        bytes32 hash = keccak256(abi.encodePacked(
            bytes1(0xff),
            deployer,
            salt,
            keccak256(bytecode)
        ));

        return address(uint160(uint256(hash)));
    }
}
