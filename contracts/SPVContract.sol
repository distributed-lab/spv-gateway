// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {LibSort} from "solady/src/utils/LibSort.sol";

import {BlockHeader, BlockHeaderData} from "./libs/BlockHeader.sol";
import {TargetsHelper} from "./libs/TargetsHelper.sol";

import {ISPVContract} from "./interfaces/ISPVContract.sol";

contract SPVContract is ISPVContract, Initializable {
    using BlockHeader for bytes;
    using TargetsHelper for bytes32;

    uint8 public constant MEDIAN_PAST_BLOCKS = 11;

    bytes32 public constant SPV_CONTRACT_STORAGE_SLOT =
        keccak256("spv.contract.spv.contract.storage");

    struct SPVContractStorage {
        mapping(bytes32 => BlockData) blocksData;
        mapping(uint256 => bytes32) blocksHeightToBlockHash;
        bytes32 mainchainHead;
        uint256 lastEpochCumulativeWork;
    }

    modifier broadcastMainchainUpdateEvent() {
        bytes32 currentMainchain_ = getMainchainHead();
        _;
        bytes32 newMainchainHead_ = getMainchainHead();

        if (currentMainchain_ != newMainchainHead_) {
            emit MainchainHeadUpdated(getBlockHeight(newMainchainHead_), newMainchainHead_);
        }
    }

    function __SPVContract_init() external initializer {
        BlockHeaderData memory genesisBlockHeader_ = BlockHeaderData({
            version: 1,
            prevBlockHash: bytes32(0),
            merkleRoot: 0x4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b,
            time: 1231006505,
            bits: 0x1d00ffff,
            nonce: 2083236893
        });
        bytes32 genesisBlockHash_ = 0x000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f;

        _addBlock(genesisBlockHeader_, genesisBlockHash_, 0);

        emit MainchainHeadUpdated(0, genesisBlockHash_);
    }

    function __SPVContract_init(
        bytes calldata blockHeaderRaw_,
        uint256 blockHeight_,
        uint256 cumulativeWork_
    ) external initializer {
        (BlockHeaderData memory blockHeader_, bytes32 blockHash_) = _parseBlockHeaderRaw(
            blockHeaderRaw_
        );

        require(
            blockHeight_ == 0 || TargetsHelper.isTargetAdjustmentBlock(blockHeight_),
            InvalidInitialBlockHeight(blockHeight_)
        );

        _addBlock(blockHeader_, blockHash_, blockHeight_);
        _getSPVContractStorage().lastEpochCumulativeWork = cumulativeWork_;

        emit MainchainHeadUpdated(blockHeight_, blockHash_);
    }

    function _getSPVContractStorage() private pure returns (SPVContractStorage storage _spvs) {
        bytes32 slot_ = SPV_CONTRACT_STORAGE_SLOT;

        assembly {
            _spvs.slot := slot_
        }
    }

    /// @inheritdoc ISPVContract
    function addBlockHeaderBatch(
        bytes[] calldata blockHeaderRawArray_
    ) external broadcastMainchainUpdateEvent {
        (
            BlockHeaderData[] memory blockHeaders_,
            bytes32[] memory blockHashes_
        ) = _parseBlockHeadersRaw(blockHeaderRawArray_);

        uint256 firstBlockHeight_ = getBlockHeight(blockHeaders_[0].prevBlockHash) + 1;
        bytes32 currentTarget_ = getBlockTarget(blockHeaders_[0].prevBlockHash);

        for (uint256 i = 0; i < blockHeaderRawArray_.length; ++i) {
            uint256 currentBlockHeight_ = firstBlockHeight_ + i;

            currentTarget_ = _updateLastEpochCumulativeWork(currentTarget_, currentBlockHeight_);

            uint32 medianTime_;

            if (i < MEDIAN_PAST_BLOCKS) {
                medianTime_ = _getStorageMedianTime(blockHeaders_[i], currentBlockHeight_);
            } else {
                medianTime_ = _getMemoryMedianTime(blockHeaders_, i);
            }

            _validateBlockRules(blockHeaders_[i], blockHashes_[i], currentTarget_, medianTime_);

            _addBlock(blockHeaders_[i], blockHashes_[i], currentBlockHeight_);
        }
    }

    /// @inheritdoc ISPVContract
    function addBlockHeader(
        bytes calldata blockHeaderRaw_
    ) external broadcastMainchainUpdateEvent {
        (BlockHeaderData memory blockHeader_, bytes32 blockHash_) = _parseBlockHeaderRaw(
            blockHeaderRaw_
        );

        require(
            blockExists(blockHeader_.prevBlockHash),
            PrevBlockDoesNotExist(blockHeader_.prevBlockHash)
        );

        uint256 blockHeight_ = getBlockHeight(blockHeader_.prevBlockHash) + 1;
        bytes32 currentTarget_ = getBlockTarget(blockHeader_.prevBlockHash);

        currentTarget_ = _updateLastEpochCumulativeWork(currentTarget_, blockHeight_);

        _validateBlockRules(
            blockHeader_,
            blockHash_,
            currentTarget_,
            _getStorageMedianTime(blockHeader_, blockHeight_)
        );

        _addBlock(blockHeader_, blockHash_, blockHeight_);
    }

    /// @inheritdoc ISPVContract
    function validateBlockHash(bytes32 blockHash_) external view returns (bool, uint256) {
        if (!isInMainchain(blockHash_)) {
            return (false, 0);
        }

        return (true, getMainchainBlockHeight() - getBlockHeight(blockHash_));
    }

    /// @inheritdoc ISPVContract
    function getBlockMerkleRoot(bytes32 blockHash_) external view returns (bytes32) {
        return _getBlockHeader(blockHash_).merkleRoot;
    }

    /// @inheritdoc ISPVContract
    function getBlockInfo(bytes32 blockHash_) external view returns (BlockInfo memory blockInfo_) {
        if (!blockExists(blockHash_)) {
            return blockInfo_;
        }

        BlockData memory blockData_ = getBlockData(blockHash_);

        blockInfo_ = BlockInfo({
            mainBlockData: blockData_,
            isInMainchain: isInMainchain(blockHash_),
            cumulativeWork: _getBlockCumulativeWork(blockData_.blockHeight, blockHash_)
        });
    }

    /// @inheritdoc ISPVContract
    function getLastEpochCumulativeWork() external view returns (uint256) {
        return _getSPVContractStorage().lastEpochCumulativeWork;
    }

    /// @inheritdoc ISPVContract
    function getMainchainHead() public view returns (bytes32) {
        return _getSPVContractStorage().mainchainHead;
    }

    /// @inheritdoc ISPVContract
    function getBlockData(bytes32 blockHash_) public view returns (BlockData memory) {
        return _getSPVContractStorage().blocksData[blockHash_];
    }

    /// @inheritdoc ISPVContract
    function getBlockHeight(bytes32 blockHash_) public view returns (uint256) {
        return _getSPVContractStorage().blocksData[blockHash_].blockHeight;
    }

    /// @inheritdoc ISPVContract
    function getBlockHash(uint256 blockHeight_) public view returns (bytes32) {
        return _getSPVContractStorage().blocksHeightToBlockHash[blockHeight_];
    }

    /// @inheritdoc ISPVContract
    function getBlockTarget(bytes32 blockHash_) public view returns (bytes32) {
        return TargetsHelper.bitsToTarget(_getBlockHeader(blockHash_).bits);
    }

    /// @inheritdoc ISPVContract
    function blockExists(bytes32 blockHash_) public view returns (bool) {
        return _getBlockHeader(blockHash_).time > 0;
    }

    /// @inheritdoc ISPVContract
    function getMainchainBlockHeight() public view returns (uint256) {
        return getBlockHeight(_getSPVContractStorage().mainchainHead);
    }

    /// @inheritdoc ISPVContract
    function isInMainchain(bytes32 blockHash_) public view returns (bool) {
        return getBlockHash(getBlockHeight(blockHash_)) == blockHash_;
    }

    function _addBlock(
        BlockHeaderData memory blockHeader_,
        bytes32 blockHash_,
        uint256 blockHeight_
    ) internal {
        SPVContractStorage storage $ = _getSPVContractStorage();

        $.blocksData[blockHash_] = BlockData({header: blockHeader_, blockHeight: blockHeight_});

        _updateMainchainHead(blockHeader_, blockHash_, blockHeight_);

        emit BlockHeaderAdded(blockHeight_, blockHash_);
    }

    function _updateMainchainHead(
        BlockHeaderData memory blockHeader_,
        bytes32 blockHash_,
        uint256 blockHeight_
    ) internal {
        SPVContractStorage storage $ = _getSPVContractStorage();

        bytes32 mainchainHead = $.mainchainHead;

        if (blockHeader_.prevBlockHash == mainchainHead || mainchainHead == 0) {
            $.mainchainHead = blockHash_;
            $.blocksHeightToBlockHash[blockHeight_] = blockHash_;

            return;
        }

        uint256 mainchainCumulativeWork_ = _getBlockCumulativeWork(
            getBlockHeight(mainchainHead),
            mainchainHead
        );
        uint256 newBlockCumulativeWork_ = _getBlockCumulativeWork(blockHeight_, blockHash_);

        if (newBlockCumulativeWork_ > mainchainCumulativeWork_) {
            $.mainchainHead = blockHash_;
            $.blocksHeightToBlockHash[blockHeight_] = blockHash_;

            bytes32 prevBlockHash_ = blockHeader_.prevBlockHash;
            uint256 prevBlockHeight_ = blockHeight_ - 1;

            do {
                $.blocksHeightToBlockHash[prevBlockHeight_] = prevBlockHash_;

                prevBlockHash_ = _getBlockHeader(prevBlockHash_).prevBlockHash;
                --prevBlockHeight_;
            } while (getBlockHash(prevBlockHeight_) != prevBlockHash_ && prevBlockHash_ != 0);
        }
    }

    function _updateLastEpochCumulativeWork(
        bytes32 currentTarget_,
        uint256 blockHeight_
    ) internal returns (bytes32) {
        SPVContractStorage storage $ = _getSPVContractStorage();

        if (TargetsHelper.isTargetAdjustmentBlock(blockHeight_)) {
            $.lastEpochCumulativeWork += TargetsHelper.countEpochCumulativeWork(currentTarget_);

            uint256 epochStartTime_ = _getBlockHeader(
                getBlockHash(blockHeight_ - TargetsHelper.DIFFICULTY_ADJUSTMENT_INTERVAL)
            ).time;
            uint256 epochEndTime_ = _getBlockHeader(getBlockHash(blockHeight_ - 1)).time;
            uint256 passedTime_ = epochEndTime_ - epochStartTime_;

            currentTarget_ = TargetsHelper.countNewRoundedTarget(currentTarget_, passedTime_);
        }

        return currentTarget_;
    }

    function _parseBlockHeadersRaw(
        bytes[] calldata blockHeaderRawArray_
    )
        internal
        view
        returns (BlockHeaderData[] memory blockHeaders_, bytes32[] memory blockHashes_)
    {
        require(blockHeaderRawArray_.length > 0, EmptyBlockHeaderArray());

        blockHeaders_ = new BlockHeaderData[](blockHeaderRawArray_.length);
        blockHashes_ = new bytes32[](blockHeaderRawArray_.length);

        for (uint256 i = 0; i < blockHeaderRawArray_.length; ++i) {
            (blockHeaders_[i], blockHashes_[i]) = _parseBlockHeaderRaw(blockHeaderRawArray_[i]);

            if (i == 0) {
                require(
                    blockExists(blockHeaders_[i].prevBlockHash),
                    PrevBlockDoesNotExist(blockHeaders_[i].prevBlockHash)
                );
            } else {
                require(
                    blockHeaders_[i].prevBlockHash == blockHashes_[i - 1],
                    InvalidBlockHeadersOrder()
                );
            }
        }
    }

    function _parseBlockHeaderRaw(
        bytes calldata blockHeaderRaw_
    ) internal view returns (BlockHeaderData memory blockHeader_, bytes32 blockHash_) {
        (blockHeader_, blockHash_) = blockHeaderRaw_.parseBlockHeaderData();

        _onlyNonExistingBlock(blockHash_);
    }

    function _getStorageMedianTime(
        BlockHeaderData memory blockHeader_,
        uint256 blockHeight_
    ) internal view returns (uint32) {
        if (blockHeight_ == 1) {
            return blockHeader_.time;
        }

        bytes32 toBlockHash_ = blockHeader_.prevBlockHash;

        if (blockHeight_ - 1 < MEDIAN_PAST_BLOCKS) {
            return _getBlockHeader(toBlockHash_).time;
        }

        uint256[] memory blocksTime_ = new uint256[](MEDIAN_PAST_BLOCKS);
        bool needsSort_;

        for (uint256 i = MEDIAN_PAST_BLOCKS; i > 0; --i) {
            uint32 currentTime_ = _getBlockHeader(toBlockHash_).time;

            blocksTime_[i - 1] = currentTime_;
            toBlockHash_ = _getBlockHeader(toBlockHash_).prevBlockHash;

            if (i < MEDIAN_PAST_BLOCKS && currentTime_ > blocksTime_[i]) {
                needsSort_ = true;
            }
        }

        return _getMedianTime(blocksTime_, needsSort_);
    }

    function _getMemoryMedianTime(
        BlockHeaderData[] memory blockHeaders_,
        uint256 to_
    ) internal pure returns (uint32) {
        if (blockHeaders_.length < MEDIAN_PAST_BLOCKS) {
            return 0;
        }

        uint256[] memory blocksTime_ = new uint256[](MEDIAN_PAST_BLOCKS);
        bool needsSort_;

        for (uint256 i = 0; i < MEDIAN_PAST_BLOCKS; ++i) {
            uint32 currentTime_ = blockHeaders_[to_ - MEDIAN_PAST_BLOCKS + i].time;

            blocksTime_[i] = currentTime_;

            if (i > 0 && currentTime_ < blocksTime_[i - 1]) {
                needsSort_ = true;
            }
        }

        return _getMedianTime(blocksTime_, needsSort_);
    }

    function _getBlockCumulativeWork(
        uint256 blockHeight_,
        bytes32 blockHash_
    ) internal view returns (uint256) {
        uint256 currentEpochCumulativeWork_ = getBlockTarget(blockHash_).countCumulativeWork(
            TargetsHelper.getEpochBlockNumber(blockHeight_) + 1
        );

        return _getSPVContractStorage().lastEpochCumulativeWork + currentEpochCumulativeWork_;
    }

    function _getBlockHeader(bytes32 blockHash_) internal view returns (BlockHeaderData storage) {
        return _getSPVContractStorage().blocksData[blockHash_].header;
    }

    function _onlyNonExistingBlock(bytes32 blockHash_) internal view {
        require(!blockExists(blockHash_), BlockAlreadyExists(blockHash_));
    }

    function _validateBlockRules(
        BlockHeaderData memory blockHeader_,
        bytes32 blockHash_,
        bytes32 target_,
        uint32 medianTime_
    ) internal pure {
        bytes32 blockTarget_ = TargetsHelper.bitsToTarget(blockHeader_.bits);

        require(target_ == blockTarget_, InvalidTarget(blockTarget_, target_));
        require(blockHash_ <= blockTarget_, InvalidBlockHash(blockHash_, blockTarget_));
        require(
            blockHeader_.time >= medianTime_,
            InvalidBlockTime(blockHeader_.time, medianTime_)
        );
    }

    function _getMedianTime(
        uint256[] memory blocksTime_,
        bool needsSort_
    ) internal pure returns (uint32) {
        if (needsSort_) {
            LibSort.insertionSort(blocksTime_);
        }

        return uint32(blocksTime_[MEDIAN_PAST_BLOCKS / 2]);
    }
}
