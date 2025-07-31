// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import "../contracts/src/CardanoEthereumResolver.sol";
import "../contracts/src/TestEscrowFactory.sol";

contract DeployCardanoEthereumResolver is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy TestEscrowFactory if needed
        TestEscrowFactory factory = new TestEscrowFactory();
        console.log("TestEscrowFactory deployed at:", address(factory));

        // Mock LOP address (replace with actual 1inch LOP address)
        address lopAddress = 0x111111254eeb25477B68fb85Ed929f73A960582;
        
        // Deploy CardanoEthereumResolver
        CardanoEthereumResolver resolver = new CardanoEthereumResolver(
            IEscrowFactory(address(factory)),
            IOrderMixin(lopAddress),
            deployer
        );
        
        console.log("CardanoEthereumResolver deployed at:", address(resolver));
        console.log("Deployer:", deployer);
        
        vm.stopBroadcast();

        // Save deployment info
        string memory deploymentInfo = string(
            abi.encodePacked(
                "{\n",
                '  "factory": "', vm.toString(address(factory)), '",\n',
                '  "resolver": "', vm.toString(address(resolver)), '",\n',
                '  "deployer": "', vm.toString(deployer), '",\n',
                '  "chain": "', vm.toString(block.chainid), '",\n',
                '  "timestamp": "', vm.toString(block.timestamp), '"\n',
                "}"
            )
        );
        
        vm.writeFile("deployment-cardano.json", deploymentInfo);
        console.log("Deployment info saved to deployment-cardano.json");
    }
}