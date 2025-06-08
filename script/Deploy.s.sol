// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/CampaignFactory.sol";
import "../src/Campaign.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy CampaignFactory
        CampaignFactory factory = new CampaignFactory();
        
        console.log("CampaignFactory deployed at:", address(factory));
        console.log("Owner:", factory.owner());

        vm.stopBroadcast();

        // Save deployment info
        string memory deploymentInfo = string(abi.encodePacked(
            "{\n",
            '  "campaignFactory": "', vm.toString(address(factory)), '",\n',
            '  "network": "', vm.envString("NETWORK_NAME"), '",\n',
            '  "deployer": "', vm.toString(vm.addr(deployerPrivateKey)), '",\n',
            '  "timestamp": "', vm.toString(block.timestamp), '"\n',
            "}"
        ));

        vm.writeFile("./deployments/latest.json", deploymentInfo);
        
        console.log("Deployment info saved to ./deployments/latest.json");
    }
}

contract DeployLocal is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy CampaignFactory
        CampaignFactory factory = new CampaignFactory();
        
        console.log("CampaignFactory deployed at:", address(factory));
        console.log("Owner:", factory.owner());

        // Create a sample campaign for testing
        string[] memory milestoneDescriptions = new string[](3);
        milestoneDescriptions[0] = "Development Phase";
        milestoneDescriptions[1] = "Testing Phase";
        milestoneDescriptions[2] = "Launch Phase";

        uint256[] memory milestoneAmounts = new uint256[](3);
        milestoneAmounts[0] = 3 ether;
        milestoneAmounts[1] = 4 ether;
        milestoneAmounts[2] = 3 ether;

        address sampleCampaign = factory.createCampaign(
            0x1234567890123456789012345678901234567890, // Sample startup address
            "Sample Campaign",
            "This is a sample campaign for testing purposes",
            10 ether,
            30 days,
            milestoneDescriptions,
            milestoneAmounts
        );

        console.log("Sample campaign created at:", sampleCampaign);

        vm.stopBroadcast();

        // Save local deployment info
        string memory deploymentInfo = string(abi.encodePacked(
            "{\n",
            '  "campaignFactory": "', vm.toString(address(factory)), '",\n',
            '  "sampleCampaign": "', vm.toString(sampleCampaign), '",\n',
            '  "network": "local",\n',
            '  "deployer": "', vm.toString(msg.sender), '",\n',
            '  "timestamp": "', vm.toString(block.timestamp), '"\n',
            "}"
        ));

        vm.writeFile("./deployments/local.json", deploymentInfo);
        
        console.log("Local deployment info saved to ./deployments/local.json");
    }
}
