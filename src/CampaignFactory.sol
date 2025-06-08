// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Campaign.sol";

/**
 * @title CampaignFactory
 * @dev Factory contract to create crowdfunding campaigns
 */
contract CampaignFactory {
    address public platformOwner;
    uint256 public platformFeePercentage; // Default platform fee percentage

    address[] public deployedCampaigns;
    mapping(address => address[]) public startupCampaigns;
    uint256 public totalCampaigns;

    // Events - Only the required ones
    event CampaignCreated(
        address indexed startup,
        address indexed campaignAddress
    );

    modifier onlyPlatformOwner() {
        require(
            msg.sender == platformOwner,
            "Only platform owner can call this function"
        );
        _;
    }

    /**
     * @dev Constructor
     */
    constructor(uint256 _platformFeePercentage) {
        require(_platformFeePercentage <= 20, "Platform fee cannot exceed 20%");
        platformOwner = msg.sender;
        platformFeePercentage = _platformFeePercentage;
    }

    /**
     * @dev Create a new campaign
     */
    function createCampaign(
        uint256 _minimumContribution,
        uint256 _targetAmount,
        uint256 _durationInDays,
        string memory _title,
        string memory _description
    ) public {
        require(
            _minimumContribution > 0,
            "Minimum contribution must be greater than 0"
        );
        require(_targetAmount > 0, "Target amount must be greater than 0");
        require(
            _durationInDays > 0 && _durationInDays <= 365,
            "Invalid duration"
        );
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");

        // Deploy new campaign contract
        Campaign newCampaign = new Campaign(
            _minimumContribution,
            _targetAmount,
            _durationInDays,
            msg.sender,
            _title,
            _description,
            platformOwner,
            platformFeePercentage
        );

        address campaignAddress = address(newCampaign);

        // Store campaign information
        deployedCampaigns.push(campaignAddress);
        startupCampaigns[msg.sender].push(campaignAddress);
        totalCampaigns++;

        emit CampaignCreated(msg.sender, campaignAddress);
    }

    /**
     * @dev Get all deployed campaigns
     */
    function getDeployedCampaigns() public view returns (address[] memory) {
        return deployedCampaigns;
    }

    /**
     * @dev Get campaigns created by a specific startup
     */
    function getCampaignsByStartup(
        address _startup
    ) public view returns (address[] memory) {
        return startupCampaigns[_startup];
    }

    /**
     * @dev Update platform fee percentage (only platform owner)
     */
    function updatePlatformFee(
        uint256 _newFeePercentage
    ) public onlyPlatformOwner {
        require(_newFeePercentage <= 20, "Platform fee cannot exceed 20%");
        platformFeePercentage = _newFeePercentage;
    }

    /**
     * @dev Transfer platform ownership (only platform owner)
     */
    function transferPlatformOwnership(
        address _newOwner
    ) public onlyPlatformOwner {
        require(_newOwner != address(0), "Invalid new owner address");
        platformOwner = _newOwner;
    }

    /**
     * @dev Get total number of campaigns
     */
    function getTotalCampaigns() public view returns (uint256) {
        return totalCampaigns;
    }

    /**
     * @dev Get platform information
     */
    function getPlatformInfo() public view returns (address, uint256) {
        return (platformOwner, platformFeePercentage);
    }
}
