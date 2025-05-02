// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BlockHeaderData} from "../../libs/BlockHeader.sol";
import {BlocksStorage} from "../../libs/BlocksStorage.sol";

contract BlocksStorageMock {
    using BlocksStorage for BlocksStorage.BlocksData;

    BlocksStorage.BlocksData internal _blocksData;

    function initialize(uint256 pendingBlockCount_) external {
        _blocksData.initialize(pendingBlockCount_);
    }

    function initialize(
        BlockHeaderData calldata startBlockHeader_,
        bytes32 startBlockHash_,
        uint256 startBlockHeight_,
        uint256 startBlockWork_,
        uint256 pendingBlockCount_
    ) external {
        _blocksData.initialize(
            startBlockHeader_,
            startBlockHash_,
            startBlockHeight_,
            startBlockWork_,
            pendingBlockCount_
        );
    }

    function addBlock(
        BlockHeaderData memory blockHeader_,
        bytes32 blockHash_,
        uint256 blockHeight_,
        uint256 blockWork_
    ) external {
        _blocksData.addBlock(blockHeader_, blockHash_, blockHeight_, blockWork_);
    }

    function getPendingBlockCount() external view returns (uint256) {
        return _blocksData.getPendingBlockCount();
    }

    function getBlockHashByBlockHeight(uint256 blockHeight_) external view returns (bytes32) {
        return _blocksData.getBlockHashByBlockHeight(blockHeight_);
    }

    function getBlockHeight(bytes32 blockHash_) external view returns (uint256) {
        return _blocksData.getBlockHeight(blockHash_);
    }

    function getPrevBlockHash(bytes32 blockHash_) external view returns (bytes32) {
        return _blocksData.getPrevBlockHash(blockHash_);
    }

    function getBlockTimeByBlockHeight(uint256 blockHeight_) external view returns (uint32) {
        return _blocksData.getBlockTimeByBlockHeight(blockHeight_);
    }

    function getBlockTime(bytes32 blockHash_) external view returns (uint32) {
        return _blocksData.getBlockTime(blockHash_);
    }

    function blockExists(bytes32 blockHash_) external view returns (bool) {
        return _blocksData.blockExists(blockHash_);
    }

    function hasStatus(
        bytes32 blockHash_,
        BlocksStorage.BlockStatus status_
    ) external view returns (bool) {
        return _blocksData.hasStatus(blockHash_, status_);
    }

    function getMainchainHeight() external view returns (uint256) {
        return _blocksData.getMainchainHeight();
    }

    function getBlockData(
        bytes32 blockHash_
    ) external view returns (BlocksStorage.BlockData memory) {
        return _blocksData.getBlockData(blockHash_);
    }

    function getNextMainchainBlock(bytes32 blockHash_) external view returns (bytes32) {
        return _blocksData.getNextMainchainBlock(blockHash_);
    }

    function isInMainchain(bytes32 blockHash_) external view returns (bool) {
        return _blocksData.isInMainchain(blockHash_);
    }

    function getBlockStatus(bytes32 blockHash_) external view returns (BlocksStorage.BlockStatus) {
        return _blocksData.getBlockStatus(blockHash_);
    }

    function getMedianTime(bytes32 toBlockHash_) external view returns (uint32) {
        return _blocksData.getMedianTime(toBlockHash_);
    }
}
