// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Donation Platform
 * @dev A transparent charitable giving platform using blockchain technology
 * @author Donation Platform Team
 */
contract Project {
    // State variables
    address public owner;
    uint256 public totalDonations;
    uint256 public totalDonors;
    uint256 public campaignCount;
    
    // Structs
    struct Campaign {
        uint256 id;
        string title;
        string description;
        address payable beneficiary;
        uint256 goalAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool isActive;
        bool goalReached;
        uint256 donorCount;
    }
    
    struct Donation {
        address donor;
        uint256 amount;
        uint256 timestamp;
        uint256 campaignId;
        string message;
    }
    
    // Mappings
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => Donation[]) public campaignDonations;
    mapping(address => uint256[]) public donorCampaigns;
    mapping(address => uint256) public totalDonatedByAddress;
    
    // Events
    event CampaignCreated(
        uint256 indexed campaignId,
        string title,
        address indexed beneficiary,
        uint256 goalAmount,
        uint256 deadline
    );
    
    event DonationMade(
        uint256 indexed campaignId,
        address indexed donor,
        uint256 amount,
        string message
    );
    
    event CampaignCompleted(
        uint256 indexed campaignId,
        uint256 totalRaised,
        bool goalReached
    );
    
    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed beneficiary,
        uint256 amount
    );
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    modifier validCampaign(uint256 _campaignId) {
        require(_campaignId > 0 && _campaignId <= campaignCount, "Invalid campaign ID");
        _;
    }
    
    modifier campaignActive(uint256 _campaignId) {
        require(campaigns[_campaignId].isActive, "Campaign is not active");
        require(block.timestamp < campaigns[_campaignId].deadline, "Campaign deadline passed");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
        campaignCount = 0;
        totalDonations = 0;
        totalDonors = 0;
    }
    
    /**
     * @dev Core Function 1: Create a new donation campaign
     * @param _title Campaign title
     * @param _description Campaign description
     * @param _beneficiary Address that will receive the donations
     * @param _goalAmount Target amount to raise (in wei)
     * @param _durationInDays Campaign duration in days
     */
    function createCampaign(
        string memory _title,
        string memory _description,
        address payable _beneficiary,
        uint256 _goalAmount,
        uint256 _durationInDays
    ) public returns (uint256) {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_description).length > 0, "Description cannot be empty");
        require(_beneficiary != address(0), "Invalid beneficiary address");
        require(_goalAmount > 0, "Goal amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        
        campaignCount++;
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);
        
        campaigns[campaignCount] = Campaign({
            id: campaignCount,
            title: _title,
            description: _description,
            beneficiary: _beneficiary,
            goalAmount: _goalAmount,
            raisedAmount: 0,
            deadline: deadline,
            isActive: true,
            goalReached: false,
            donorCount: 0
        });
        
        emit CampaignCreated(
            campaignCount,
            _title,
            _beneficiary,
            _goalAmount,
            deadline
        );
        
        return campaignCount;
    }
    
    /**
     * @dev Core Function 2: Make a donation to a specific campaign
     * @param _campaignId ID of the campaign to donate to
     * @param _message Optional message from the donor
     */
    function donate(uint256 _campaignId, string memory _message) 
        public 
        payable 
        validCampaign(_campaignId) 
        campaignActive(_campaignId) 
    {
        require(msg.value > 0, "Donation amount must be greater than 0");
        
        Campaign storage campaign = campaigns[_campaignId];
        
        // Record the donation
        campaignDonations[_campaignId].push(Donation({
            donor: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp,
            campaignId: _campaignId,
            message: _message
        }));
        
        // Update campaign stats
        campaign.raisedAmount += msg.value;
        campaign.donorCount++;
        
        // Update global stats
        totalDonations += msg.value;
        
        // Track donor's campaigns if first donation
        bool isNewDonor = totalDonatedByAddress[msg.sender] == 0;
        if (isNewDonor) {
            totalDonors++;
        }
        
        totalDonatedByAddress[msg.sender] += msg.value;
        donorCampaigns[msg.sender].push(_campaignId);
        
        // Check if goal is reached
        if (campaign.raisedAmount >= campaign.goalAmount && !campaign.goalReached) {
            campaign.goalReached = true;
        }
        
        emit DonationMade(_campaignId, msg.sender, msg.value, _message);
    }
    
    /**
     * @dev Core Function 3: Withdraw funds from a campaign (only beneficiary)
     * @param _campaignId ID of the campaign to withdraw from
     */
    function withdrawFunds(uint256 _campaignId) 
        public 
        validCampaign(_campaignId) 
    {
        Campaign storage campaign = campaigns[_campaignId];
        
        require(msg.sender == campaign.beneficiary, "Only beneficiary can withdraw funds");
        require(campaign.raisedAmount > 0, "No funds to withdraw");
        require(
            block.timestamp >= campaign.deadline || campaign.goalReached,
            "Campaign is still active and goal not reached"
        );
        
        uint256 amount = campaign.raisedAmount;
        campaign.raisedAmount = 0;
        campaign.isActive = false;
        
        // Transfer funds to beneficiary
        campaign.beneficiary.transfer(amount);
        
        emit FundsWithdrawn(_campaignId, campaign.beneficiary, amount);
        emit CampaignCompleted(_campaignId, amount, campaign.goalReached);
    }
    
    // View functions for transparency
    function getCampaignDetails(uint256 _campaignId) 
        public 
        view 
        validCampaign(_campaignId) 
        returns (
            uint256 id,
            string memory title,
            string memory description,
            address beneficiary,
            uint256 goalAmount,
            uint256 raisedAmount,
            uint256 deadline,
            bool isActive,
            bool goalReached,
            uint256 donorCount
        ) 
    {
        Campaign memory campaign = campaigns[_campaignId];
        return (
            campaign.id,
            campaign.title,
            campaign.description,
            campaign.beneficiary,
            campaign.goalAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.isActive,
            campaign.goalReached,
            campaign.donorCount
        );
    }
    
    function getCampaignDonations(uint256 _campaignId) 
        public 
        view 
        validCampaign(_campaignId) 
        returns (Donation[] memory) 
    {
        return campaignDonations[_campaignId];
    }
    
    function getDonorCampaigns(address _donor) 
        public 
        view 
        returns (uint256[] memory) 
    {
        return donorCampaigns[_donor];
    }
    
    function getPlatformStats() 
        public 
        view 
        returns (
            uint256 _totalDonations,
            uint256 _totalDonors,
            uint256 _campaignCount
        ) 
    {
        return (totalDonations, totalDonors, campaignCount);
    }
    
    // Emergency functions (only owner)
    function emergencyPause(uint256 _campaignId) 
        public 
        onlyOwner 
        validCampaign(_campaignId) 
    {
        campaigns[_campaignId].isActive = false;
    }
    
    function emergencyResume(uint256 _campaignId) 
        public 
        onlyOwner 
        validCampaign(_campaignId) 
    {
        require(block.timestamp < campaigns[_campaignId].deadline, "Campaign deadline passed");
        campaigns[_campaignId].isActive = true;
    }
}
