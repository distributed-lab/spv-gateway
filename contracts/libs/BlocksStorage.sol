// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {LibSort} from "solady/src/utils/LibSort.sol";
import {LibBit} from "solady/src/utils/LibBit.sol";

import {BlockHeaderData} from "./BlockHeader.sol";
import {TargetsHelper} from "./targets/TargetsHelper.sol";

library BlocksStorage {
    using LibBit for uint256;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    uint8 public constant MEDIAN_PAST_BLOCKS = 11;

    error BlocksStorageAlreadyInitialized();
    error BlocksStorageNotInitialized();

    enum BlockStatus {
        Unknown,
        Pending,
        Stale,
        Active
    }

    struct BlockData {
        BlockHeaderData header;
        uint256 blockHeight;
        uint256 cumulativeWork;
    }

    struct BlocksData {
        mapping(bytes32 => BlockData) blocksData;
        mapping(bytes32 => bytes32) mainchain;
        mapping(uint256 => bytes32) heightToBlockHash;
        uint256 currentBlockHeight;
        uint256 pendingBlockCount;
    }

    modifier onlyInitialized(BlocksData storage self) {
        _onlyInitialized(self);
        _;
    }

    function initialize(BlocksData storage self, uint256 pendingBlockCount_) internal {
        BlockHeaderData memory genesisBlockHeader_ = BlockHeaderData({
            version: 1,
            prevBlockHash: bytes32(0),
            merkleRoot: 0x4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b,
            time: 1231006505,
            bits: 0x1d00ffff,
            nonce: 2083236893
        });
        bytes32 genesisBlockHash_ = 0x000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f;
        uint256 genesisBlockWork_ = TargetsHelper.countBlockWork(TargetsHelper.INITIAL_TARGET);

        _initialize(
            self,
            genesisBlockHeader_,
            genesisBlockHash_,
            0,
            genesisBlockWork_,
            pendingBlockCount_
        );
    }

    function initialize(
        BlocksData storage self,
        BlockHeaderData memory startBlockHeader_,
        bytes32 startBlockHash_,
        uint256 startBlockHeight_,
        uint256 startBlockWork_,
        uint256 pendingBlockCount_
    ) internal {
        _initialize(
            self,
            startBlockHeader_,
            startBlockHash_,
            startBlockHeight_,
            startBlockWork_,
            pendingBlockCount_
        );
    }

    function _initialize(
        BlocksData storage self,
        BlockHeaderData memory startBlockHeader_,
        bytes32 startBlockHash_,
        uint256 startBlockHeight_,
        uint256 startBlockWork_,
        uint256 pendingBlockCount_
    ) private {
        require(!_isInitialized(self), BlocksStorageAlreadyInitialized());

        _addBlock(self, startBlockHeader_, startBlockHash_, startBlockHeight_, startBlockWork_);

        self.pendingBlockCount = pendingBlockCount_;
    }

    function addBlock(
        BlocksData storage self,
        BlockHeaderData memory blockHeader_,
        bytes32 blockHash_,
        uint256 blockHeight_,
        uint256 blockWork_
    ) internal onlyInitialized(self) {
        _addBlock(self, blockHeader_, blockHash_, blockHeight_, blockWork_);
    }

    function getBlockHashByBlockHeight(
        BlocksData storage self,
        uint256 blockHeight_
    ) internal view returns (bytes32) {
        return self.heightToBlockHash[blockHeight_];
    }

    function getBlockHeight(
        BlocksData storage self,
        bytes32 blockHash_
    ) internal view returns (uint256) {
        return self.blocksData[blockHash_].blockHeight;
    }

    function getPrevBlockHash(
        BlocksData storage self,
        bytes32 blockHash_
    ) internal view returns (bytes32) {
        return self.blocksData[blockHash_].header.prevBlockHash;
    }

    function getBlockTimeByBlockHeight(
        BlocksData storage self,
        uint256 blockHeight_
    ) internal view returns (uint32) {
        return getBlockTime(self, self.heightToBlockHash[blockHeight_]);
    }

    function getBlockTime(
        BlocksData storage self,
        bytes32 blockHash_
    ) internal view returns (uint32) {
        return self.blocksData[blockHash_].header.time;
    }

    function blockExists(
        BlocksData storage self,
        bytes32 blockHash_
    ) internal view returns (bool) {
        return getBlockStatus(self, blockHash_) != BlockStatus.Unknown;
    }

    function hasStatus(
        BlocksData storage self,
        bytes32 blockHash_,
        BlockStatus status_
    ) internal view returns (bool) {
        return getBlockStatus(self, blockHash_) == status_;
    }

    function getBlockStatus(
        BlocksData storage self,
        bytes32 blockHash_
    ) internal view returns (BlockStatus) {
        BlockData storage blockData = self.blocksData[blockHash_];

        if (blockData.cumulativeWork == 0) {
            return BlockStatus.Unknown;
        }

        uint256 blockHeight_ = blockData.blockHeight;

        if (blockHeight_ + self.pendingBlockCount > self.currentBlockHeight) {
            return BlockStatus.Pending;
        }

        if (self.mainchain[blockData.header.prevBlockHash] != blockHash_) {
            return BlockStatus.Stale;
        }

        return BlockStatus.Active;
    }

    function getMedianTime(
        BlocksData storage self,
        bytes32 toBlockHash_
    ) internal view returns (uint32) {
        uint256 blockHeight_ = self.blocksData[toBlockHash_].blockHeight;

        if (blockHeight_ <= MEDIAN_PAST_BLOCKS || self.currentBlockHeight < MEDIAN_PAST_BLOCKS) {
            return 0;
        }

        uint256[] memory blocksTime = new uint256[](MEDIAN_PAST_BLOCKS);
        uint256 blocksTimeIndex = MEDIAN_PAST_BLOCKS - 1;

        for (uint256 i = blockHeight_ - MEDIAN_PAST_BLOCKS; i < blockHeight_; ++i) {
            blocksTime[blocksTimeIndex--] = self.blocksData[toBlockHash_].header.time;

            toBlockHash_ = self.blocksData[toBlockHash_].header.prevBlockHash;
        }

        LibSort.insertionSort(blocksTime);

        return uint32(blocksTime[MEDIAN_PAST_BLOCKS / 2]);
    }

    function _addBlock(
        BlocksData storage self,
        BlockHeaderData memory blockHeader_,
        bytes32 blockHash_,
        uint256 blockHeight_,
        uint256 blockWork_
    ) private {
        uint256 newBlockCumulativeWork_ = self
            .blocksData[blockHeader_.prevBlockHash]
            .cumulativeWork + blockWork_;

        self.blocksData[blockHash_] = BlockData({
            header: blockHeader_,
            blockHeight: blockHeight_,
            cumulativeWork: newBlockCumulativeWork_
        });

        bytes32 mainchainHead_ = self.heightToBlockHash[self.currentBlockHeight];

        if (self.blocksData[mainchainHead_].cumulativeWork < newBlockCumulativeWork_) {
            _updateMainchain(self, blockHash_);
        }
    }

    function _updateMainchain(BlocksData storage self, bytes32 blockHash_) private {
        BlockData storage blockData = self.blocksData[blockHash_];
        bytes32 prevBlockHash_ = blockData.header.prevBlockHash;

        do {
            self.mainchain[prevBlockHash_] = blockHash_;
            self.heightToBlockHash[blockData.blockHeight] = blockHash_;

            blockHash_ = prevBlockHash_;
            blockData = self.blocksData[blockHash_];
            prevBlockHash_ = blockData.header.prevBlockHash;
        } while (self.mainchain[prevBlockHash_] != blockHash_);
    }

    function _onlyInitialized(BlocksData storage self) private view {
        require(_isInitialized(self), BlocksStorageNotInitialized());
    }

    function _isInitialized(BlocksData storage self) private view returns (bool) {
        return self.pendingBlockCount > 0;
    }
}
