// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/CampaignFactory.sol";
import "../src/Campaign.sol";

contract CampaignFactoryTest is Test {
    CampaignFactory public factory;
    address public startup1 = address(0x1);
    address public startup2 = address(0x2);

    string[] milestoneDescriptions;
    uint256[] milestoneAmounts;

    function setUp() public {
        factory = new CampaignFactory();

        // Setup milestone data
        milestoneDescriptions.push("Development");
        milestoneDescriptions.push("Testing");
        milestoneDescriptions.push("Launch");

        milestoneAmounts.push(3 ether);
        milestoneAmounts.push(4 ether);
        milestoneAmounts.push(3 ether);
    }

    function testCreateCampaign() public {
        address campaignAddress = factory.createCampaign(
            startup1,
            "Test Campaign",
            "Description",
            10 ether,
            30 days,
            milestoneDescriptions,
            milestoneAmounts
        );

        assertTrue(campaignAddress != address(0));
        assertTrue(factory.isValidCampaign(campaignAddress));
        assertEq(factory.getCampaignsCount(), 1);

        address[] memory deployedCampaigns = factory.getDeployedCampaigns();
        assertEq(deployedCampaigns[0], campaignAddress);
    }

    function testGetStartupCampaigns() public {
        // Create campaigns for startup1
        address campaign1 = factory.createCampaign(
            startup1,
            "Campaign 1",
            "Description 1",
            10 ether,
            30 days,
            milestoneDescriptions,
            milestoneAmounts
        );

        address campaign2 = factory.createCampaign(
            startup1,
            "Campaign 2",
            "Description 2",
            15 ether,
            45 days,
            milestoneDescriptions,
            milestoneAmounts
        );

        // Create campaign for startup2
        factory.createCampaign(
            startup2,
            "Campaign 3",
            "Description 3",
            20 ether,
            60 days,
            milestoneDescriptions,
            milestoneAmounts
        );

        address[] memory startup1Campaigns = factory.getStartupCampaigns(startup1);
        assertEq(startup1Campaigns.length, 2);
        assertEq(startup1Campaigns[0], campaign1);
        assertEq(startup1Campaigns[1], campaign2);

        address[] memory startup2Campaigns = factory.getStartupCampaigns(startup2);
        assertEq(startup2Campaigns.length, 1);
    }

    function testGetCampaignsPaginated() public {
        // Create multiple campaigns
        for (uint i = 0; i < 5; i++) {
            factory.createCampaign(
                startup1,
                string(abi.encodePacked("Campaign ", i)),
                "Description",
                10 ether,
                30 days,
                milestoneDescriptions,
                milestoneAmounts
            );
        }

        // Test pagination
        (address[] memory campaigns, uint256 total) = factory.getCampaignsPaginated(0, 3);
        assertEq(campaigns.length, 3);
        assertEq(total, 5);

        (campaigns, total) = factory.getCampaignsPaginated(3, 3);
        assertEq(campaigns.length, 2);
        assertEq(total, 5);
    }

    function testGetActiveCampaigns() public {
        // Create active campaign
        address activeCampaign = factory.createCampaign(
            startup1,
            "Active Campaign",
            "Description",
            10 ether,
            30 days,
            milestoneDescriptions,
            milestoneAmounts
        );

        address[] memory activeCampaigns = factory.getActiveCampaigns();
        assertEq(activeCampaigns.length, 1);
        assertEq(activeCampaigns[0], activeCampaign);
    }

    function testGetFactoryStats() public {
        // Create campaigns
        address campaign1 = factory.createCampaign(
            startup1,
            "Campaign 1",
            "Description",
            10 ether,
            30 days,
            milestoneDescriptions,
            milestoneAmounts
        );

        factory.createCampaign(
            startup2,
            "Campaign 2",
            "Description",
            15 ether,
            45 days,
            milestoneDescriptions,
            milestoneAmounts
        );

        // Fund one campaign to make it successful
        vm.deal(address(this), 100 ether);
        Campaign(campaign1).contribute{value: 10 ether}();

        (uint256 total, uint256 active, uint256 successful, uint256 totalRaised) = factory.getFactoryStats();
        
        assertEq(total, 2);
        assertEq(active, 1); // One is successful, one is active
        assertEq(successful, 1);
        assertEq(totalRaised, 10 ether);
    }

    function testGetCampaignSummary() public {
        address campaignAddress = factory.createCampaign(
            startup1,
            "Test Campaign",
            "Description",
            10 ether,
            30 days,
            milestoneDescriptions,
            milestoneAmounts
        );

        (
            address startup,
            string memory title,
            uint256 goal,
            uint256 totalRaised,
            uint256 deadline,
            Campaign.CampaignState state,
            uint256 contributorsCount,
            uint256 progress
        ) = factory.getCampaignSummary(campaignAddress);

        assertEq(startup, startup1);
        assertEq(title, "Test Campaign");
        assertEq(goal, 10 ether);
        assertEq(totalRaised, 0);
        assertEq(uint(state), uint(Campaign.CampaignState.Active));
        assertEq(contributorsCount, 0);
        assertEq(progress, 0);
    }

    function testCannotCreateCampaignWithInvalidParams() public {
        // Test invalid startup address
        vm.expectRevert("Invalid startup address");
        factory.createCampaign(
            address(0),
            "Test",
            "Description",
            10 ether,
            30 days,
            milestoneDescriptions,
            milestoneAmounts
        );

        // Test empty title
        vm.expectRevert("Title cannot be empty");
        factory.createCampaign(
            startup1,
            "",
            "Description",
            10 ether,
            30 days,
            milestoneDescriptions,
            milestoneAmounts
        );

        // Test zero goal
        vm.expectRevert("Goal must be greater than 0");
        factory.createCampaign(
            startup1,
            "Test",
            "Description",
            0,
            30 days,
            milestoneDescriptions,
            milestoneAmounts
        );
    }

    function testOwnerFunctions() public {
        address newOwner = address(0x999);
        
        factory.updateOwner(newOwner);
        assertEq(factory.owner(), newOwner);
    }

    function testOnlyOwnerCanUpdateOwner() public {
        vm.prank(startup1);
        vm.expectRevert("Only owner can call this function");
        factory.updateOwner(startup1);
    }
}
