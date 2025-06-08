// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Campaign.sol";
import "forge-std/console.sol";

contract CampaignFactory {
    // Events
    event CampaignCreated(
        address indexed campaignAddress,
        address indexed startup,
        string title,
        uint256 goal,
        uint256 deadline,
        uint256 timestamp
    );

    // Storage
    address[] public deployedCampaigns;
    mapping(address => address[]) public startupCampaigns;
    mapping(address => bool) public isCampaign;
    address public owner;

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // Create a new campaign
    function createCampaign(
        address _startup,
        string memory _title,
        string memory _description,
        uint256 _goal,
        uint256 _duration,
        string[] memory _milestoneDescriptions,
        uint256[] memory _milestoneAmounts
    ) external returns (address) {
        require(_startup != address(0), "Invalid startup address");
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_goal > 0, "Goal must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");
        require(_milestoneDescriptions.length > 0, "At least one milestone required");
        require(_milestoneDescriptions.length == _milestoneAmounts.length, "Milestone arrays length mismatch");

        // Deploy new campaign contract
        Campaign newCampaign = new Campaign(
            _startup,
            _title,
            _description,
            _goal,
            _duration,
            _milestoneDescriptions,
            _milestoneAmounts
        );

        address campaignAddress = address(newCampaign);
        
        // Store campaign
        deployedCampaigns.push(campaignAddress);
        startupCampaigns[_startup].push(campaignAddress);
        isCampaign[campaignAddress] = true;

        emit CampaignCreated(
            campaignAddress,
            _startup,
            _title,
            _goal,
            block.timestamp + _duration,
            block.timestamp
        );

        return campaignAddress;
    }

    // Get all deployed campaigns
    function getDeployedCampaigns() external view returns (address[] memory) {
        return deployedCampaigns;
    }

    // Get campaigns for a specific startup
    function getStartupCampaigns(address _startup) external view returns (address[] memory) {
        return startupCampaigns[_startup];
    }

    // Get total number of campaigns
    function getCampaignsCount() external view returns (uint256) {
        return deployedCampaigns.length;
    }

    // Get campaign details by index
    function getCampaignByIndex(uint256 _index) external view returns (
        address campaignAddress,
        address startup,
        string memory title,
        string memory description,
        uint256 goal,
        uint256 deadline,
        uint256 totalRaised,
        Campaign.CampaignState state,
        uint256 contributorsCount
    ) {
        require(_index < deployedCampaigns.length, "Invalid campaign index");
        
        Campaign campaign = Campaign(deployedCampaigns[_index]);
        return campaign.getCampaignInfo();
    }

    // Get multiple campaigns with pagination
    function getCampaignsPaginated(uint256 _offset, uint256 _limit) 
        external 
        view 
        returns (address[] memory campaigns, uint256 total) 
    {
        total = deployedCampaigns.length;
        
        if (_offset >= total) {
            return (new address[](0), total);
        }
        
        uint256 end = _offset + _limit;
        if (end > total) {
            end = total;
        }
        
        campaigns = new address[](end - _offset);
        for (uint256 i = _offset; i < end; i++) {
            campaigns[i - _offset] = deployedCampaigns[i];
        }
        
        return (campaigns, total);
    }

    // Get active campaigns
    function getActiveCampaigns() external view returns (address[] memory) {
        uint256 activeCount = 0;
        
        // First pass: count active campaigns
        for (uint256 i = 0; i < deployedCampaigns.length; i++) {
            Campaign campaign = Campaign(deployedCampaigns[i]);
            if (campaign.state() == Campaign.CampaignState.Active && 
                block.timestamp < campaign.deadline()) {
                activeCount++;
            }
        }
        
        // Second pass: collect active campaigns
        address[] memory activeCampaigns = new address[](activeCount);
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < deployedCampaigns.length; i++) {
            Campaign campaign = Campaign(deployedCampaigns[i]);
            if (campaign.state() == Campaign.CampaignState.Active && 
                block.timestamp < campaign.deadline()) {
                activeCampaigns[currentIndex] = deployedCampaigns[i];
                currentIndex++;
            }
        }
        
        return activeCampaigns;
    }

    // Get successful campaigns
    function getSuccessfulCampaigns() external view returns (address[] memory) {
        uint256 successfulCount = 0;
        
        // First pass: count successful campaigns
        for (uint256 i = 0; i < deployedCampaigns.length; i++) {
            Campaign campaign = Campaign(deployedCampaigns[i]);
            if (campaign.state() == Campaign.CampaignState.Successful) {
                successfulCount++;
            }
        }
        
        // Second pass: collect successful campaigns
        address[] memory successfulCampaigns = new address[](successfulCount);
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < deployedCampaigns.length; i++) {
            Campaign campaign = Campaign(deployedCampaigns[i]);
            if (campaign.state() == Campaign.CampaignState.Successful) {
                successfulCampaigns[currentIndex] = deployedCampaigns[i];
                currentIndex++;
            }
        }
        
        return successfulCampaigns;
    }

    // Check if address is a valid campaign
    function isValidCampaign(address _campaign) external view returns (bool) {
        return isCampaign[_campaign];
    }

    // Get factory statistics
    function getFactoryStats() external view returns (
        uint256 totalCampaigns,
        uint256 activeCampaigns,
        uint256 successfulCampaigns,
        uint256 totalRaised
    ) {
        totalCampaigns = deployedCampaigns.length;
        uint256 activeCount = 0;
        uint256 successfulCount = 0;
        uint256 totalRaisedAmount = 0;
        
        for (uint256 i = 0; i < deployedCampaigns.length; i++) {
            Campaign campaign = Campaign(deployedCampaigns[i]);
            
            if (campaign.state() == Campaign.CampaignState.Active && 
                block.timestamp < campaign.deadline()) {
                activeCount++;
            }
            
            if (campaign.state() == Campaign.CampaignState.Successful) {
                successfulCount++;
            }
            
            totalRaisedAmount += campaign.totalRaised();
        }
        
        return (totalCampaigns, activeCount, successfulCount, totalRaisedAmount);
    }

    // Emergency functions (only owner)
    function updateOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid new owner address");
        owner = _newOwner;
    }

    // Get campaign summary for frontend
    function getCampaignSummary(address _campaignAddress) external view returns (
        address startup,
        string memory title,
        uint256 goal,
        uint256 totalRaised,
        uint256 deadline,
        Campaign.CampaignState state,
        uint256 contributorsCount,
        uint256 progress
    ) {
        require(isCampaign[_campaignAddress], "Invalid campaign address");
        
        Campaign campaign = Campaign(_campaignAddress);
        
        (startup, title, , goal, deadline, totalRaised, state, contributorsCount) = campaign.getCampaignInfo();
        progress = campaign.getProgress();
        
        return (startup, title, goal, totalRaised, deadline, state, contributorsCount, progress);
    }
}
