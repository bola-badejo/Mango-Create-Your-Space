// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MangoChainAnchor
/// @notice Publishes MangoChain block hashes to a public chain. Once a hash
/// is anchored, the operator cannot rewrite MangoChain history up to that
/// block without the mismatch being visible to anyone.
contract MangoChainAnchor {
    address public immutable publisher;
    uint64 public latestHeight;
    bytes32 public latestHash;
    mapping(uint64 => bytes32) public anchors;

    event Anchored(uint64 indexed height, bytes32 blockHash, uint256 timestamp);

    error NotPublisher();
    error HeightNotIncreasing();
    error EmptyHash();

    constructor(address publisher_) {
        publisher = publisher_;
    }

    function anchor(uint64 height, bytes32 blockHash) external {
        if (msg.sender != publisher) revert NotPublisher();
        if (blockHash == bytes32(0)) revert EmptyHash();
        if (latestHash != bytes32(0) && height <= latestHeight) revert HeightNotIncreasing();
        anchors[height] = blockHash;
        latestHeight = height;
        latestHash = blockHash;
        emit Anchored(height, blockHash, block.timestamp);
    }
}
