// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {AddressDataEntropy} from "../src/implementations/AddressDataEntropy.sol";

contract MinimalDeploy is Script {
    bytes32 private constant DEFAULT_SALT = keccak256("AddressDataEntropy");
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address owner = vm.envOr("OWNER", deployer);
        address[3] memory entropyAddresses = getEntropyConfig();
        bytes32 salt = vm.envOr("DEPLOY_SALT", DEFAULT_SALT);

        console.log("[INFO] Starting AddressDataEntropy deployment...");
        console.log("[INFO] Deployer:", deployer);
        console.log("[INFO] Owner:", owner);
        console.log("[INFO] Network:", block.chainid);

        vm.startBroadcast(deployerKey);
        AddressDataEntropy deployed = new AddressDataEntropy{salt: salt}(
            owner,
            entropyAddresses
        );
        vm.stopBroadcast();
        require(deployed.owner() == owner, "Deployment verification failed");
        console.log("[SUCCESS] AddressDataEntropy deployed to:", address(deployed));
        console.log("[INFO] Owner verified:", deployed.owner());
        console.log("[INFO] Entropy addresses configured successfully");
        console.log("[OK] Deployment completed");
    }

    function getEntropyConfig() public view returns (address[3] memory) {
        address[3] memory addresses;
        addresses[0] = vm.envOr("ENTROPY_ADDRESS_1", address(0));
        addresses[1] = vm.envOr("ENTROPY_ADDRESS_2", address(0));
        addresses[2] = vm.envOr("ENTROPY_ADDRESS_3", address(0));
        address[3] memory defaults = getNetworkDefaults();
        if (addresses[0] == address(0)) addresses[0] = defaults[0];
        if (addresses[1] == address(0)) addresses[1] = defaults[1];
        if (addresses[2] == address(0)) addresses[2] = defaults[2];
        console.log("[INFO] Entropy Address 1:", addresses[0]);
        console.log("[INFO] Entropy Address 2:", addresses[1]);
        console.log("[INFO] Entropy Address 3:", addresses[2]);

        return addresses;
    }

    function getNetworkDefaults() public view returns (address[3] memory) {
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));

        if (block.chainid == 1) {
            return [address(0x1), address(0x2), address(0x3)];
        } else if (block.chainid == 11155111) {
            return [address(0x1), address(0x2), address(0x3)];
        } else {
            return [
                deployer,
                address(uint160(deployer) + 1),
                address(uint160(deployer) + 2)
            ];
        }
    }
}
