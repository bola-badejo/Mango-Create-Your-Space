// MangoToken.sol - Production Ready
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MangoToken is ERC20, ERC20Burnable, Ownable, Pausable {
    using SafeMath for uint256;
    
    // Sustainable tokenomics
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10**18; // 100M total
    uint256 public constant INITIAL_SUPPLY = 10_000_000 * 10**18; // 10M initial
    
    // Activity rewards - SMALL amounts
    uint256 public constant DAILY_LOGIN_REWARD = 0.01 * 10**18; // 0.01 MNG
    uint256 public constant CREATE_POST_REWARD = 0.05 * 10**18; // 0.05 MNG  
    uint256 public constant SEND_MESSAGE_REWARD = 0.001 * 10**18; // 0.001 MNG
    
    // Anti-spam mechanisms
    mapping(address => uint256) public lastActivity;
    mapping(address => uint256) public dailyRewardCount;
    mapping(address => uint256) public lastRewardDate;
    
    // Treasury
    address public treasuryWallet;
    uint256 public treasuryBalance;
    
    // Events
    event ActivityReward(address indexed user, uint256 amount, string activity);
    event TreasuryDeposit(uint256 amount);
    
    constructor(address _treasuryWallet) ERC20("Mango Token", "MNG") {
        require(_treasuryWallet != address(0), "Invalid treasury wallet");
        
        treasuryWallet = _treasuryWallet;
        
        // Initial distribution - SMALL amounts
        _mint(_treasuryWallet, INITIAL_SUPPLY); // All to treasury initially
        treasuryBalance = INITIAL_SUPPLY;
    }
    
    // Sustainable activity rewards - VERY SMALL amounts
    function rewardActivity(address user, string memory activity) external onlyOwner returns (uint256) {
        require(user != address(0), "Invalid user");
        require(totalSupply() < MAX_SUPPLY, "Max supply reached");
        
        // Anti-spam: Max 10 rewards per day per user
        if (block.timestamp - lastRewardDate[user] > 1 days) {
            dailyRewardCount[user] = 0;
            lastRewardDate[user] = block.timestamp;
        }
        require(dailyRewardCount[user] < 10, "Daily reward limit reached");
        
        uint256 rewardAmount = _getRewardAmount(activity);
        require(rewardAmount > 0, "Invalid activity");
        require(treasuryBalance >= rewardAmount, "Insufficient treasury funds");
        
        // Transfer from treasury to user
        treasuryBalance -= rewardAmount;
        _transfer(treasuryWallet, user, rewardAmount);
        
        dailyRewardCount[user]++;
        lastActivity[user] = block.timestamp;
        
        emit ActivityReward(user, rewardAmount, activity);
        return rewardAmount;
    }
    
    function _getRewardAmount(string memory activity) internal pure returns (uint256) {
        if (keccak256(abi.encodePacked(activity)) == keccak256(abi.encodePacked("daily_login"))) {
            return DAILY_LOGIN_REWARD;
        } else if (keccak256(abi.encodePacked(activity)) == keccak256(abi.encodePacked("create_post"))) {
            return CREATE_POST_REWARD;
        } else if (keccak256(abi.encodePacked(activity)) == keccak256(abi.encodePacked("send_message"))) {
            return SEND_MESSAGE_REWARD;
        } else if (keccak256(abi.encodePacked(activity)) == keccak256(abi.encodePacked("like_content"))) {
            return 0.001 * 10**18; // 0.001 MNG
        } else if (keccak256(abi.encodePacked(activity)) == keccak256(abi.encodePacked("share_content"))) {
            return 0.002 * 10**18; // 0.002 MNG
        }
        return 0;
    }
    
    // Treasury management
    function depositToTreasury(uint256 amount) external onlyOwner {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        _transfer(msg.sender, treasuryWallet, amount);
        treasuryBalance += amount;
        
        emit TreasuryDeposit(amount);
    }
    
    function getTreasuryBalance() external view returns (uint256) {
        return treasuryBalance;
    }
    
    // Emergency functions
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    // Override transfer with pause functionality
    function _beforeTokenTransfer(
        address from,
        address to, 
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        require(!paused(), "Token transfers paused");
    }
}