// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Campaign
 * @dev Individual crowdfunding campaign contract
 */
contract Campaign {
    enum CampaignStatus {
        ACTIVE,
        FUNDED,
        FAILED
    }

    address public startup;
    address public platformOwner;
    uint256 public minimumContribution;
    uint256 public targetAmount;
    uint256 public deadline;
    uint256 public amountRaised;
    uint256 public platformFeePercentage; // Percentage (e.g., 5 = 5%)
    CampaignStatus public status;
    string public campaignTitle;
    string public campaignDescription;

    mapping(address => uint256) public investors;
    address[] public investorsList;
    uint256 public investorsCount;

    // Events - Only the required ones
    event InvestmentMade(
        address indexed investor,
        address indexed campaign,
        uint256 amount
    );

    event CampaignEnded(address indexed campaign, CampaignStatus status);

    modifier onlyStartup() {
        require(msg.sender == startup, "Only startup can call this function");
        _;
    }

    /**
     * @dev Constructor to initialize campaign
     */
    constructor(
        uint256 _minimumContribution,
        uint256 _targetAmount,
        uint256 _durationInDays,
        address _startup,
        string memory _title,
        string memory _description,
        address _platformOwner,
        uint256 _platformFeePercentage
    ) {
        require(
            _minimumContribution > 0,
            "Minimum contribution must be greater than 0"
        );
        require(_targetAmount > 0, "Target amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        require(_startup != address(0), "Invalid startup address");
        require(_platformOwner != address(0), "Invalid platform owner address");
        require(_platformFeePercentage <= 20, "Platform fee cannot exceed 20%");

        startup = _startup;
        platformOwner = _platformOwner;
        minimumContribution = _minimumContribution;
        targetAmount = _targetAmount;
        deadline = block.timestamp + (_durationInDays * 1 days);
        campaignTitle = _title;
        campaignDescription = _description;
        platformFeePercentage = _platformFeePercentage;
        status = CampaignStatus.ACTIVE;
    }

    /**
     * @dev Check campaign validity and update status if needed
     */
    function _checkCampaignValidity() internal {
        if (status != CampaignStatus.ACTIVE) {
            return;
        }

        // Check if deadline passed
        if (block.timestamp >= deadline) {
            status = CampaignStatus.FAILED;
            emit CampaignEnded(address(this), CampaignStatus.FAILED);
            _processRefunds();
            return;
        }

        // Check if target amount reached
        if (amountRaised >= targetAmount) {
            status = CampaignStatus.FUNDED;
            emit CampaignEnded(address(this), CampaignStatus.FUNDED);
            _transferFunds();
            return;
        }
    }

    /**
     * @dev Transfer funds to startup and platform owner when target is reached
     */
    function _transferFunds() internal {
        uint256 totalBalance = address(this).balance;
        uint256 platformFee = (totalBalance * platformFeePercentage) / 100;
        uint256 startupAmount = totalBalance - platformFee;

        // Transfer platform fee
        if (platformFee > 0) {
            payable(platformOwner).transfer(platformFee);
        }

        // Transfer remaining amount to startup
        if (startupAmount > 0) {
            payable(startup).transfer(startupAmount);
        }
    }

    /**
     * @dev Process refunds for all investors when campaign fails
     */
    function _processRefunds() internal {
        for (uint256 i = 0; i < investorsList.length; i++) {
            address investor = investorsList[i];
            uint256 refundAmount = investors[investor];

            if (refundAmount > 0) {
                investors[investor] = 0;
                payable(investor).transfer(refundAmount);
            }
        }
    }

    /**
     * @dev Invest in the campaign
     */
    function invest() public payable {
        require(
            msg.value >= minimumContribution,
            "Investment below minimum amount"
        );

        // Check campaign validity first
        _checkCampaignValidity();

        // If campaign is no longer active, revert
        require(status == CampaignStatus.ACTIVE, "Campaign is not active");

        // If first time investor, add to investors list
        if (investors[msg.sender] == 0) {
            investorsList.push(msg.sender);
            investorsCount++;
        }

        investors[msg.sender] += msg.value;
        amountRaised += msg.value;

        emit InvestmentMade(msg.sender, address(this), msg.value);

        // Check if this investment reached the target
        _checkCampaignValidity();
    }

    /**
     * @dev Force check campaign status (can be called by anyone)
     */
    function checkAndUpdateStatus() public {
        _checkCampaignValidity();
    }

    /**
     * @dev Get all investors and their investment amounts
     */
    function getInvestorsAndAmounts()
        public
        view
        returns (address[] memory, uint256[] memory)
    {
        uint256[] memory amounts = new uint256[](investorsList.length);

        for (uint256 i = 0; i < investorsList.length; i++) {
            amounts[i] = investors[investorsList[i]];
        }

        return (investorsList, amounts);
    }

    /**
     * @dev Get campaign summary
     */
    function getSummary()
        public
        view
        returns (
            uint256, // minimumContribution
            uint256, // targetAmount
            uint256, // amountRaised
            uint256, // investorsCount
            uint256, // deadline
            address, // startup
            CampaignStatus, // status
            string memory, // title
            string memory // description
        )
    {
        return (
            minimumContribution,
            targetAmount,
            amountRaised,
            investorsCount,
            deadline,
            startup,
            status,
            campaignTitle,
            campaignDescription
        );
    }

    /**
     * @dev Get time left in campaign
     */
    function getTimeLeft() public view returns (uint256) {
        if (block.timestamp >= deadline) {
            return 0;
        }
        return deadline - block.timestamp;
    }

    /**
     * @dev Get contract balance
     */
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Get investment amount for specific investor
     */
    function getInvestmentAmount(
        address _investor
    ) public view returns (uint256) {
        return investors[_investor];
    }
}
