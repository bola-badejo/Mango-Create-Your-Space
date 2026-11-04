// contracts/SocialRewardDistributor.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SocialRewardDistributor is ReentrancyGuard, Ownable {
    MangoSocialToken public token;
    
    // Reward tiers - immutable after deployment
    uint256 public constant DAILY_LOGIN_REWARD = 0.01 * 10**18;
    uint256 public constant CREATE_POST_REWARD = 0.02 * 10**18;
    uint256 public constant UPLOAD_MUSIC_REWARD = 0.05 * 10**18;
    uint256 public constant UPLOAD_VIDEO_REWARD = 0.10 * 10**18;
    uint256 public constant INVITE_FRIEND_REWARD = 0.25 * 10**18;
    
    // Anti-spam mechanisms
    uint256 public constant DAILY_REWARD_LIMIT = 20;
    uint256 public constant REWARD_COOLDOWN = 3600; // 1 hour
    
    mapping(address => uint256) public lastRewardDate;
    mapping(address => uint256) public dailyRewardCount;
    mapping(address => mapping(bytes32 => bool)) public claimedRewards;
    
    event RewardClaimed(address user, uint256 amount, string activity, bytes32 contentHash);
    
    constructor(address tokenAddress) {
        token = MangoSocialToken(tokenAddress);
    }
    
    function claimReward(
        string calldata activity,
        bytes32 contentHash,
        uint256 timestamp,
        bytes calldata signature
    ) external nonReentrant returns (uint256) {
        address user = msg.sender;
        
        // Validate signature (prevent replay attacks)
        bytes32 messageHash = keccak256(abi.encodePacked(
            user, activity, contentHash, timestamp, address(this)
        ));
        address signer = _recoverSigner(messageHash, signature);
        require(signer == owner(), "Invalid signature");
        
        // Anti-spam checks
        require(!claimedRewards[user][contentHash], "Reward already claimed");
        require(block.timestamp >= timestamp, "Invalid timestamp");
        require(block.timestamp <= timestamp + 1 hours, "Signature expired");
        
        _resetDailyCounter(user);
        require(dailyRewardCount[user] < DAILY_REWARD_LIMIT, "Daily limit reached");
        
        uint256 reward = _getRewardAmount(activity);
        require(reward > 0, "Invalid activity");
        
        // Distribute reward
        require(
            token.distributeReward(user, reward, activity),
            "Reward distribution failed"
        );
        
        claimedRewards[user][contentHash] = true;
        dailyRewardCount[user]++;
        lastRewardDate[user] = block.timestamp;
        
        emit RewardClaimed(user, reward, activity, contentHash);
        return reward;
    }
    
    function _getRewardAmount(string calldata activity) internal pure returns (uint256) {
        bytes32 activityHash = keccak256(abi.encodePacked(activity));
        
        if (activityHash == keccak256(abi.encodePacked("daily_login"))) 
            return DAILY_LOGIN_REWARD;
        if (activityHash == keccak256(abi.encodePacked("create_post"))) 
            return CREATE_POST_REWARD;
        if (activityHash == keccak256(abi.encodePacked("upload_music"))) 
            return UPLOAD_MUSIC_REWARD;
        if (activityHash == keccak256(abi.encodePacked("upload_video"))) 
            return UPLOAD_VIDEO_REWARD;
        if (activityHash == keccak256(abi.encodePacked("invite_friend"))) 
            return INVITE_FRIEND_REWARD;
            
        return 0;
    }
    
    function _resetDailyCounter(address user) internal {
        if (block.timestamp - lastRewardDate[user] > 1 days) {
            dailyRewardCount[user] = 0;
            lastRewardDate[user] = block.timestamp;
        }
    }
    
    function _recoverSigner(bytes32 messageHash, bytes memory signature) 
        internal pure returns (address) 
    {
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32", messageHash
        ));
        
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(signature);
        return ecrecover(ethSignedMessageHash, v, r, s);
    }
    
    function _splitSignature(bytes memory sig) 
        internal pure returns (bytes32 r, bytes32 s, uint8 v) 
    {
        require(sig.length == 65, "Invalid signature length");
        
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        
        if (v < 27) v += 27;
    }
    
    // Emergency functions (timelocked in production)
    function emergencyWithdraw(address tokenAddress) external onlyOwner {
        // Only for stuck tokens, not MNG tokens
        require(tokenAddress != address(token), "Cannot withdraw MNG tokens");
        IERC20(tokenAddress).transfer(owner(), IERC20(tokenAddress).balanceOf(address(this)));
    }
}

