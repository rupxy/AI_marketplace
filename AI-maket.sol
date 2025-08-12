// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title AI Personality Marketplace
 * @dev A decentralized marketplace for trading AI behavioral patterns and personalities
 */
contract AIPersonalityMarketplace {
    
    struct AIPersonality {
        uint256 id;
        string name;
        string behaviorHash; // IPFS hash containing AI behavioral data
        address creator;
        uint256 price;
        bool isActive;
        uint256 downloads;
        uint256 rating; // Average rating (1-5 scale, multiplied by 100)
        uint256 totalRatings;
    }
    
    mapping(uint256 => AIPersonality) public personalities;
    mapping(address => uint256[]) public userPersonalities;
    mapping(uint256 => mapping(address => bool)) public hasPurchased;
    mapping(uint256 => mapping(address => bool)) public hasRated;
    
    uint256 public nextPersonalityId = 1;
    uint256 public platformFee = 250; // 2.5% in basis points
    address public owner;
    
    event PersonalityListed(uint256 indexed id, string name, address indexed creator, uint256 price);
    event PersonalityPurchased(uint256 indexed id, address indexed buyer, uint256 price);
    event PersonalityRated(uint256 indexed id, address indexed rater, uint256 rating);
    event PersonalityUpdated(uint256 indexed id, uint256 newPrice, bool isActive);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyCreator(uint256 _personalityId) {
        require(personalities[_personalityId].creator == msg.sender, "Only creator can modify");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev List a new AI personality for sale
     * @param _name Name of the AI personality
     * @param _behaviorHash IPFS hash containing behavioral patterns and training data
     * @param _price Price in wei for purchasing this personality
     */
    function listPersonality(
        string memory _name,
        string memory _behaviorHash,
        uint256 _price
    ) external {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_behaviorHash).length > 0, "Behavior hash cannot be empty");
        require(_price > 0, "Price must be greater than 0");
        
        uint256 personalityId = nextPersonalityId++;
        
        personalities[personalityId] = AIPersonality({
            id: personalityId,
            name: _name,
            behaviorHash: _behaviorHash,
            creator: msg.sender,
            price: _price,
            isActive: true,
            downloads: 0,
            rating: 0,
            totalRatings: 0
        });
        
        userPersonalities[msg.sender].push(personalityId);
        
        emit PersonalityListed(personalityId, _name, msg.sender, _price);
    }
    
    /**
     * @dev Purchase an AI personality
     * @param _personalityId ID of the personality to purchase
     */
    function purchasePersonality(uint256 _personalityId) external payable {
        AIPersonality storage personality = personalities[_personalityId];
        
        require(personality.id != 0, "Personality does not exist");
        require(personality.isActive, "Personality is not active");
        require(msg.value >= personality.price, "Insufficient payment");
        require(!hasPurchased[_personalityId][msg.sender], "Already purchased");
        require(personality.creator != msg.sender, "Cannot purchase own personality");
        
        // Calculate platform fee
        uint256 fee = (personality.price * platformFee) / 10000;
        uint256 creatorPayment = personality.price - fee;
        
        // Transfer payments
        payable(personality.creator).transfer(creatorPayment);
        payable(owner).transfer(fee);
        
        // Refund excess payment
        if (msg.value > personality.price) {
            payable(msg.sender).transfer(msg.value - personality.price);
        }
        
        // Update records
        hasPurchased[_personalityId][msg.sender] = true;
        personality.downloads++;
        
        emit PersonalityPurchased(_personalityId, msg.sender, personality.price);
    }
    
    /**
     * @dev Rate a purchased AI personality
     * @param _personalityId ID of the personality to rate
     * @param _rating Rating from 1 to 5
     */
    function ratePersonality(uint256 _personalityId, uint256 _rating) external {
        require(personalities[_personalityId].id != 0, "Personality does not exist");
        require(_rating >= 1 && _rating <= 5, "Rating must be between 1 and 5");
        require(hasPurchased[_personalityId][msg.sender], "Must purchase before rating");
        require(!hasRated[_personalityId][msg.sender], "Already rated this personality");
        
        AIPersonality storage personality = personalities[_personalityId];
        
        // Update rating calculation
        uint256 totalScore = (personality.rating * personality.totalRatings) + (_rating * 100);
        personality.totalRatings++;
        personality.rating = totalScore / personality.totalRatings;
        
        hasRated[_personalityId][msg.sender] = true;
        
        emit PersonalityRated(_personalityId, msg.sender, _rating);
    }
    
    /**
     * @dev Update personality price and active status (only creator)
     * @param _personalityId ID of the personality to update
     * @param _newPrice New price for the personality
     * @param _isActive Whether the personality should be active for sale
     */
    function updatePersonality(
        uint256 _personalityId,
        uint256 _newPrice,
        bool _isActive
    ) external onlyCreator(_personalityId) {
        require(personalities[_personalityId].id != 0, "Personality does not exist");
        require(_newPrice > 0, "Price must be greater than 0");
        
        AIPersonality storage personality = personalities[_personalityId];
        personality.price = _newPrice;
        personality.isActive = _isActive;
        
        emit PersonalityUpdated(_personalityId, _newPrice, _isActive);
    }
    
    /**
     * @dev Get personality details
     * @param _personalityId ID of the personality
     * @return id The personality ID
     * @return name The personality name
     * @return behaviorHash The IPFS hash containing behavioral data
     * @return creator The address of the personality creator
     * @return price The price in wei
     * @return isActive Whether the personality is active for sale
     * @return downloads The number of times downloaded
     * @return rating The average rating (multiplied by 100)
     * @return totalRatings The total number of ratings received
     */
    function getPersonality(uint256 _personalityId) external view returns (
        uint256 id,
        string memory name,
        string memory behaviorHash,
        address creator,
        uint256 price,
        bool isActive,
        uint256 downloads,
        uint256 rating,
        uint256 totalRatings
    ) {
        AIPersonality memory personality = personalities[_personalityId];
        require(personality.id != 0, "Personality does not exist");
        
        return (
            personality.id,
            personality.name,
            personality.behaviorHash,
            personality.creator,
            personality.price,
            personality.isActive,
            personality.downloads,
            personality.rating,
            personality.totalRatings
        );
    }
    
    // View functions for frontend integration
    function getUserPersonalities(address _user) external view returns (uint256[] memory) {
        return userPersonalities[_user];
    }
    
    function hasUserPurchased(uint256 _personalityId, address _user) external view returns (bool) {
        return hasPurchased[_personalityId][_user];
    }
    
    function hasUserRated(uint256 _personalityId, address _user) external view returns (bool) {
        return hasRated[_personalityId][_user];
    }
}

