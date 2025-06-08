// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console.sol";

contract Campaign {
    // Campaign states
    enum CampaignState {
        Active,
        Successful,
        Failed,
        Cancelled
    }

    // Milestone structure
    struct Milestone {
        string description;
        uint256 amount;
        bool completed;
        bool fundsReleased;
        uint256 completedAt;
    }

    // Campaign details
    address public owner;
    address public startup;
    string public title;
    string public description;
    uint256 public goal;
    uint256 public deadline;
    uint256 public createdAt;
    CampaignState public state;
    
    // Financial tracking
    uint256 public totalRaised;
    uint256 public totalWithdrawn;
    mapping(address => uint256) public contributions;
    address[] public contributors;
    
    // Milestones
    Milestone[] public milestones;
    uint256 public currentMilestone;
    
    // Events
    event ContributionMade(address indexed contributor, uint256 amount, uint256 totalRaised);
    event MilestoneCompleted(uint256 indexed milestoneIndex, uint256 amount);
    event FundsWithdrawn(uint256 amount, uint256 milestoneIndex);
    event CampaignStateChanged(CampaignState newState);
    event RefundIssued(address indexed contributor, uint256 amount);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyStartup() {
        require(msg.sender == startup, "Only startup can call this function");
        _;
    }

    modifier campaignActive() {
        require(state == CampaignState.Active, "Campaign is not active");
        require(block.timestamp < deadline, "Campaign deadline has passed");
        _;
    }

    modifier campaignEnded() {
        require(block.timestamp >= deadline || state != CampaignState.Active, "Campaign is still active");
        _;
    }

    constructor(
        address _startup,
        string memory _title,
        string memory _description,
        uint256 _goal,
        uint256 _duration,
        string[] memory _milestoneDescriptions,
        uint256[] memory _milestoneAmounts
    ) {
        require(_startup != address(0), "Invalid startup address");
        require(_goal > 0, "Goal must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");
        require(_milestoneDescriptions.length == _milestoneAmounts.length, "Milestone arrays length mismatch");
        
        owner = msg.sender;
        startup = _startup;
        title = _title;
        description = _description;
        goal = _goal;
        deadline = block.timestamp + _duration;
        createdAt = block.timestamp;
        state = CampaignState.Active;
        currentMilestone = 0;

        // Initialize milestones
        uint256 totalMilestoneAmount = 0;
        for (uint256 i = 0; i < _milestoneDescriptions.length; i++) {
            milestones.push(Milestone({
                description: _milestoneDescriptions[i],
                amount: _milestoneAmounts[i],
                completed: false,
                fundsReleased: false,
                completedAt: 0
            }));
            totalMilestoneAmount += _milestoneAmounts[i];
        }
        
        require(totalMilestoneAmount == _goal, "Total milestone amounts must equal goal");
    }

    // Contribute to the campaign
    function contribute() external payable campaignActive {
        require(msg.value > 0, "Contribution must be greater than 0");
        
        // Track new contributor
        if (contributions[msg.sender] == 0) {
            contributors.push(msg.sender);
        }
        
        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;
        
        emit ContributionMade(msg.sender, msg.value, totalRaised);
        
        // Check if goal is reached
        if (totalRaised >= goal) {
            state = CampaignState.Successful;
            emit CampaignStateChanged(CampaignState.Successful);
        }
    }

    // Complete a milestone (only startup can call)
    function completeMilestone(uint256 milestoneIndex) external onlyStartup {
        require(milestoneIndex < milestones.length, "Invalid milestone index");
        require(!milestones[milestoneIndex].completed, "Milestone already completed");
        require(milestoneIndex == currentMilestone, "Must complete milestones in order");
        require(state == CampaignState.Successful, "Campaign must be successful");
        
        milestones[milestoneIndex].completed = true;
        milestones[milestoneIndex].completedAt = block.timestamp;
        currentMilestone++;
        
        emit MilestoneCompleted(milestoneIndex, milestones[milestoneIndex].amount);
    }

    // Withdraw funds for completed milestone (only startup can call)
    function withdrawMilestoneFunds(uint256 milestoneIndex) external onlyStartup {
        require(milestoneIndex < milestones.length, "Invalid milestone index");
        require(milestones[milestoneIndex].completed, "Milestone not completed");
        require(!milestones[milestoneIndex].fundsReleased, "Funds already released");
        require(state == CampaignState.Successful, "Campaign must be successful");
        
        uint256 amount = milestones[milestoneIndex].amount;
        require(address(this).balance >= amount, "Insufficient contract balance");
        
        milestones[milestoneIndex].fundsReleased = true;
        totalWithdrawn += amount;
        
        (bool success, ) = payable(startup).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit FundsWithdrawn(amount, milestoneIndex);
    }

    // Get refund if campaign failed (contributors can call)
    function getRefund() external campaignEnded {
        require(state == CampaignState.Failed || (block.timestamp >= deadline && totalRaised < goal), "Refund not available");
        require(contributions[msg.sender] > 0, "No contribution to refund");
        
        uint256 refundAmount = contributions[msg.sender];
        contributions[msg.sender] = 0;
        
        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, "Refund transfer failed");
        
        emit RefundIssued(msg.sender, refundAmount);
    }

    // Cancel campaign (only owner can call)
    function cancelCampaign() external onlyOwner {
        require(state == CampaignState.Active, "Campaign is not active");
        state = CampaignState.Cancelled;
        emit CampaignStateChanged(CampaignState.Cancelled);
    }

    // Update campaign state based on conditions
    function updateCampaignState() external {
        if (block.timestamp >= deadline && state == CampaignState.Active) {
            if (totalRaised >= goal) {
                state = CampaignState.Successful;
            } else {
                state = CampaignState.Failed;
            }
            emit CampaignStateChanged(state);
        }
    }

    // View functions
    function getContributors() external view returns (address[] memory) {
        return contributors;
    }

    function getContributorsCount() external view returns (uint256) {
        return contributors.length;
    }

    function getMilestone(uint256 index) external view returns (Milestone memory) {
        require(index < milestones.length, "Invalid milestone index");
        return milestones[index];
    }

    function getMilestonesCount() external view returns (uint256) {
        return milestones.length;
    }

    function getAllMilestones() external view returns (Milestone[] memory) {
        return milestones;
    }

    function getCampaignInfo() external view returns (
        address _startup,
        string memory _title,
        string memory _description,
        uint256 _goal,
        uint256 _deadline,
        uint256 _totalRaised,
        CampaignState _state,
        uint256 _contributorsCount
    ) {
        return (
            startup,
            title,
            description,
            goal,
            deadline,
            totalRaised,
            state,
            contributors.length
        );
    }

    function getProgress() external view returns (uint256 percentage) {
        if (goal == 0) return 0;
        return (totalRaised * 100) / goal;
    }

    function getDaysLeft() external view returns (uint256) {
        if (block.timestamp >= deadline) return 0;
        return (deadline - block.timestamp) / 1 days;
    }

    // Fallback function to receive Ether
    receive() external payable {
        contribute();
    }
}
