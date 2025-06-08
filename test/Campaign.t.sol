// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Campaign.sol";

contract CampaignTest is Test {
    Campaign public campaign;
    address public startup = address(0x1);
    address public contributor1 = address(0x2);
    address public contributor2 = address(0x3);
    address public owner = address(this);

    string[] milestoneDescriptions;
    uint256[] milestoneAmounts;

    function setUp() public {
        // Setup milestone data
        milestoneDescriptions.push("Development Phase");
        milestoneDescriptions.push("Testing Phase");
        milestoneDescriptions.push("Launch Phase");

        milestoneAmounts.push(3 ether);
        milestoneAmounts.push(4 ether);
        milestoneAmounts.push(3 ether);

        // Deploy campaign
        campaign = new Campaign(
            startup,
            "Test Campaign",
            "A test campaign for unit testing",
            10 ether, // goal
            30 days,  // duration
            milestoneDescriptions,
            milestoneAmounts
        );

        // Fund test accounts
        vm.deal(contributor1, 100 ether);
        vm.deal(contributor2, 100 ether);
    }

    function testCampaignInitialization() public {
        assertEq(campaign.startup(), startup);
        assertEq(campaign.title(), "Test Campaign");
        assertEq(campaign.goal(), 10 ether);
        assertEq(uint(campaign.state()), uint(Campaign.CampaignState.Active));
        assertEq(campaign.getMilestonesCount(), 3);
    }

    function testContribute() public {
        vm.prank(contributor1);
        campaign.contribute{value: 2 ether}();

        assertEq(campaign.totalRaised(), 2 ether);
        assertEq(campaign.contributions(contributor1), 2 ether);
        assertEq(campaign.getContributorsCount(), 1);
    }

    function testContributeReachesGoal() public {
        vm.prank(contributor1);
        campaign.contribute{value: 6 ether}();

        vm.prank(contributor2);
        campaign.contribute{value: 4 ether}();

        assertEq(campaign.totalRaised(), 10 ether);
        assertEq(uint(campaign.state()), uint(Campaign.CampaignState.Successful));
    }

    function testCompleteMilestone() public {
        // First reach the goal
        vm.prank(contributor1);
        campaign.contribute{value: 10 ether}();

        // Complete first milestone
        vm.prank(startup);
        campaign.completeMilestone(0);

        Campaign.Milestone memory milestone = campaign.getMilestone(0);
        assertTrue(milestone.completed);
        assertEq(campaign.currentMilestone(), 1);
    }

    function testWithdrawMilestoneFunds() public {
        // Reach goal
        vm.prank(contributor1);
        campaign.contribute{value: 10 ether}();

        // Complete and withdraw first milestone
        vm.prank(startup);
        campaign.completeMilestone(0);

        uint256 startupBalanceBefore = startup.balance;
        
        vm.prank(startup);
        campaign.withdrawMilestoneFunds(0);

        assertEq(startup.balance, startupBalanceBefore + 3 ether);
        assertEq(campaign.totalWithdrawn(), 3 ether);
    }

    function testRefund() public {
        // Contribute but don't reach goal
        vm.prank(contributor1);
        campaign.contribute{value: 2 ether}();

        // Fast forward past deadline
        vm.warp(block.timestamp + 31 days);

        // Update campaign state
        campaign.updateCampaignState();
        assertEq(uint(campaign.state()), uint(Campaign.CampaignState.Failed));

        // Get refund
        uint256 balanceBefore = contributor1.balance;
        vm.prank(contributor1);
        campaign.getRefund();

        assertEq(contributor1.balance, balanceBefore + 2 ether);
        assertEq(campaign.contributions(contributor1), 0);
    }

    function testCannotContributeAfterDeadline() public {
        // Fast forward past deadline
        vm.warp(block.timestamp + 31 days);

        vm.prank(contributor1);
        vm.expectRevert("Campaign deadline has passed");
        campaign.contribute{value: 1 ether}();
    }

    function testCannotCompleteMilestoneOutOfOrder() public {
        // Reach goal
        vm.prank(contributor1);
        campaign.contribute{value: 10 ether}();

        // Try to complete milestone 1 before milestone 0
        vm.prank(startup);
        vm.expectRevert("Must complete milestones in order");
        campaign.completeMilestone(1);
    }

    function testOnlyStartupCanCompleteMilestone() public {
        // Reach goal
        vm.prank(contributor1);
        campaign.contribute{value: 10 ether}();

        // Try to complete milestone as non-startup
        vm.prank(contributor1);
        vm.expectRevert("Only startup can call this function");
        campaign.completeMilestone(0);
    }

    function testGetProgress() public {
        vm.prank(contributor1);
        campaign.contribute{value: 5 ether}();

        assertEq(campaign.getProgress(), 50); // 50%
    }

    function testReceiveFunction() public {
        vm.prank(contributor1);
        (bool success,) = address(campaign).call{value: 1 ether}("");
        assertTrue(success);
        assertEq(campaign.totalRaised(), 1 ether);
    }
}
