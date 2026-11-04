// contracts/MultiSigTreasury.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MultiSigTreasury {
    address[] public owners;
    uint256 public required;
    uint256 public constant TIMELOCK_DURATION = 2 days;
    
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 timestamp;
    }
    
    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;
    uint256 public transactionCount;
    
    event Deposit(address indexed sender, uint256 value);
    event Submission(uint256 indexed transactionId);
    event Confirmation(address indexed sender, uint256 indexed transactionId);
    event Execution(uint256 indexed transactionId);
    event ExecutionFailure(uint256 indexed transactionId);
    
    modifier onlyOwner() {
        require(isOwner(msg.sender), "Not owner");
        _;
    }
    
    modifier notExecuted(uint256 transactionId) {
        require(!transactions[transactionId].executed, "Already executed");
        _;
    }
    
    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(_required > 0 && _required <= _owners.length, "Invalid required number");
        
        owners = _owners;
        required = _required;
    }
    
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }
    
    function submitTransaction(address to, uint256 value, bytes calldata data) 
        external onlyOwner returns (uint256) 
    {
        uint256 transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            to: to,
            value: value,
            data: data,
            executed: false,
            timestamp: block.timestamp + TIMELOCK_DURATION
        });
        transactionCount += 1;
        
        emit Submission(transactionId);
        confirmTransaction(transactionId);
        
        return transactionId;
    }
    
    function confirmTransaction(uint256 transactionId) 
        public onlyOwner notExecuted(transactionId) 
    {
        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);
        
        // Auto-execute if enough confirmations and timelock passed
        if (isConfirmed(transactionId) && block.timestamp >= transactions[transactionId].timestamp) {
            executeTransaction(transactionId);
        }
    }
    
    function executeTransaction(uint256 transactionId) 
        public onlyOwner notExecuted(transactionId) 
    {
        require(isConfirmed(transactionId), "Not confirmed");
        require(block.timestamp >= transactions[transactionId].timestamp, "Timelock active");
        
        Transaction storage txn = transactions[transactionId];
        txn.executed = true;
        
        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        if (success) {
            emit Execution(transactionId);
        } else {
            emit ExecutionFailure(transactionId);
            txn.executed = false;
        }
    }
    
    function isConfirmed(uint256 transactionId) public view returns (bool) {
        uint256 count = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[transactionId][owners[i]]) count++;
            if (count == required) return true;
        }
        return false;
    }
    
    function isOwner(address account) public view returns (bool) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == account) return true;
        }
        return false;
    }
    
    function getOwners() public view returns (address[] memory) {
        return owners;
    }
}

