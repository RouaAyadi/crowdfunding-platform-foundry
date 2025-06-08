// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";
import "../src/CampaignFactory.sol"; // adjust path if needed

contract DeployCampaignFactoryScript is Script {
    function setUp() public {}

    function run() public {
        // Load the deployer's private key from environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        uint256 platformFeePercentage = 5;
        // Deploy the CampaignFactory contract
        CampaignFactory factory = new CampaignFactory(platformFeePercentage);

        vm.stopBroadcast();

        console.log("CampaignFactory deployed at:", address(factory));
    }
}
