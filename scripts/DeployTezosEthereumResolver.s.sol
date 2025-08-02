// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import "../src/TezosEthereumResolver.sol";

/**
 * @title DeployTezosEthereumResolver
 * @notice Deployment script for TezosEthereumResolver contract
 */
contract DeployTezosEthereumResolver is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Get factory and LOP addresses
        address factory = vm.envAddress("FACTORY_ADDRESS");
        address limitOrderProtocol = vm.envAddress("LIMIT_ORDER_PROTOCOL_ADDRESS");
        
        console.log("Deploying TezosEthereumResolver...");
        console.log("Deployer:", deployer);
        console.log("Factory:", factory);
        console.log("Limit Order Protocol:", limitOrderProtocol);
        
        vm.startBroadcast(deployerPrivateKey);
        
        TezosEthereumResolver resolver = new TezosEthereumResolver(
            factory,
            limitOrderProtocol
        );
        
        vm.stopBroadcast();
        
        console.log("TezosEthereumResolver deployed at:", address(resolver));
        console.log("Transaction completed successfully!");
        
        // Save deployment info
        string memory deploymentInfo = string.concat(
            '{\n',
            '  "tezosResolver": "', vm.toString(address(resolver)), '",\n',
            '  "factory": "', vm.toString(factory), '",\n',
            '  "limitOrderProtocol": "', vm.toString(limitOrderProtocol), '",\n',
            '  "deployer": "', vm.toString(deployer), '",\n',
            '  "network": "sepolia",\n',
            '  "timestamp": "', vm.toString(block.timestamp), '"\n',
            '}'
        );
        
        vm.writeFile("deployment-tezos-testnet.json", deploymentInfo);
        console.log("Deployment info saved to deployment-tezos-testnet.json");
    }
}
