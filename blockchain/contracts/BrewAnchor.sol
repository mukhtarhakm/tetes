// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract BrewAnchor {
    struct Anchor {
        bytes32 headHash;
        uint64 seq;
        uint64 anchoredAt;
    }

    address public owner;
    mapping(bytes32 => Anchor) public latest;

    event Anchored(bytes32 indexed userKey, bytes32 headHash, uint64 seq, uint64 anchoredAt);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error InvalidOwner();
    error InvalidHeadHash();
    error SequenceNotIncreasing();

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function anchor(bytes32 userKey, bytes32 headHash, uint64 seq) external onlyOwner {
        if (headHash == bytes32(0)) revert InvalidHeadHash();
        if (seq <= latest[userKey].seq) revert SequenceNotIncreasing();

        uint64 anchoredAt = uint64(block.timestamp);
        latest[userKey] = Anchor(headHash, seq, anchoredAt);
        emit Anchored(userKey, headHash, seq, anchoredAt);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidOwner();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
