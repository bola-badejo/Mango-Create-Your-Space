// contracts/MangoSocialToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MangoSocialToken is ERC20, ReentrancyGuard {
    // Immutable constants - CANNOT be changed
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10**18; // 100M
    uint256 public constant INITIAL_TREASURY = 10_000_000 * 10**18; // 10M
    uint256 public constant PLATFORM_FEE = 100; // 1%
    address public immutable TREASURY;
    address public immutable REWARD_DISTRIBUTOR;
    
    // Anti-bot mechanisms
    mapping(address => uint256) public lastTransfer;
    uint256 public transferCooldown = 300; // 5 minutes
    
    // Events for transparency
    event TokensMinted(address indexed to, uint256 amount, string reason);
    event PlatformFeeCollected(address from, uint256 amount);
    event TransferWithFee(address from, address to, uint256 netAmount, uint256 fee);
    
    modifier onlyRewardDistributor() {
        require(msg.sender == REWARD_DISTRIBUTOR, "Not reward distributor");
        _;
    }
    
    constructor(address treasury, address rewardDistributor) 
        ERC20("Mango Social Token", "MNG") 
    {
        require(treasury != address(0), "Invalid treasury");
        require(rewardDistributor != address(0), "Invalid reward distributor");
        
        TREASURY = treasury;
        REWARD_DISTRIBUTOR = rewardDistributor;
        
        // Mint initial supply to treasury
        _mint(treasury, INITIAL_TREASURY);
        emit TokensMinted(treasury, INITIAL_TREASURY, "initial_treasury");
    }
    
    // Secure token distribution with anti-bot
    function distributeReward(
        address to, 
        uint256 amount, 
        string calldata activity
    ) external onlyRewardDistributor nonReentrant returns (bool) {
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Invalid amount");
        require(totalSupply() + amount <= MAX_SUPPLY, "Max supply exceeded");
        
        _mint(to, amount);
        emit TokensMinted(to, amount, activity);
        return true;
    }
    
    // Override transfer with fee and anti-bot
    function transfer(address to, uint256 amount) 
        public 
        override 
        nonReentrant 
        returns (bool) 
    {
        _validateTransfer(msg.sender, to, amount);
        
        uint256 fee = (amount * PLATFORM_FEE) / 10000;
        uint256 netAmount = amount - fee;
        
        // Collect fee
        if (fee > 0) {
            _transfer(msg.sender, TREASURY, fee);
            emit PlatformFeeCollected(msg.sender, fee);
        }
        
        _transfer(msg.sender, to, netAmount);
        emit TransferWithFee(msg.sender, to, netAmount, fee);
        
        lastTransfer[msg.sender] = block.timestamp;
        lastTransfer[to] = block.timestamp;
        
        return true;
    }
    
    function _validateTransfer(address from, address to, uint256 amount) internal view {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(amount > 0, "Transfer amount must be positive");
        require(balanceOf(from) >= amount, "Insufficient balance");
        
        // Anti-bot cooldown
        require(
            block.timestamp >= lastTransfer[from] + transferCooldown,
            "Transfer cooldown active"
        );
    }
    
    // NO ADMIN FUNCTIONS - completely decentralized
    // Contract is immutable after deployment
}

