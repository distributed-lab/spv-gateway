// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {BlockHeader} from "@solarity/solidity-lib/libs/bitcoin/BlockHeader.sol";
import {TxMerkleProof} from "@solarity/solidity-lib/libs/bitcoin/TxMerkleProof.sol";
import {EndianConverter} from "@solarity/solidity-lib/libs/utils/EndianConverter.sol";

import {LibSort} from "solady/src/utils/LibSort.sol";

import {TargetsHelper} from "./libs/TargetsHelper.sol";

import {ISPVGateway} from "./interfaces/ISPVGateway.sol";

contract SPVGateway is ISPVGateway, Initializable {
    using BlockHeader for bytes;
    using TargetsHelper for bytes32;
    using EndianConverter for bytes32;

    uint8 public constant MEDIAN_PAST_BLOCKS = 11;

    bytes32 public constant SPV_GATEWAY_STORAGE_SLOT =
        keccak256("spv.gateway.spv.gateway.storage");

    struct SPVGatewayStorage {
        mapping(bytes32 => BlockData) blocksData;
        mapping(uint64 => bytes32) blocksHeightToBlockHash;
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

    function __SPVGateway_init() external initializer {
        BlockHeader.HeaderData memory genesisBlockHeader_ = BlockHeader.HeaderData({
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

    function __SPVGateway_init(
        bytes calldata blockHeaderRaw_,
        uint64 blockHeight_,
        uint256 cumulativeWork_
    ) external initializer {
        (BlockHeader.HeaderData memory blockHeader_, bytes32 blockHash_) = _parseBlockHeaderRaw(
            blockHeaderRaw_
        );

        require(
            blockHeight_ == 0 || TargetsHelper.isTargetAdjustmentBlock(blockHeight_),
            InvalidInitialBlockHeight(blockHeight_)
        );

        _addBlock(blockHeader_, blockHash_, blockHeight_);
        _getSPVGatewayStorage().lastEpochCumulativeWork = cumulativeWork_;

        emit MainchainHeadUpdated(blockHeight_, blockHash_);
    }

    function _getSPVGatewayStorage() private pure returns (SPVGatewayStorage storage _spvs) {
        bytes32 slot_ = SPV_GATEWAY_STORAGE_SLOT;

        assembly {
            _spvs.slot := slot_
        }
    }

    /// @inheritdoc ISPVGateway
    function addBlockHeaderBatch(
        bytes[] calldata blockHeaderRawArray_
    ) external broadcastMainchainUpdateEvent {
        (
            BlockHeader.HeaderData[] memory blockHeaders_,
            bytes32[] memory blockHashes_
        ) = _parseBlockHeadersRaw(blockHeaderRawArray_);

        uint64 firstBlockHeight_ = getBlockHeight(blockHeaders_[0].prevBlockHash) + 1;
        bytes32 currentTarget_ = getBlockTarget(blockHeaders_[0].prevBlockHash);

        for (uint64 i = 0; i < blockHeaderRawArray_.length; ++i) {
            uint64 currentBlockHeight_ = firstBlockHeight_ + i;

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

    /// @inheritdoc ISPVGateway
    function addBlockHeader(
        bytes calldata blockHeaderRaw_
    ) external broadcastMainchainUpdateEvent {
        (BlockHeader.HeaderData memory blockHeader_, bytes32 blockHash_) = _parseBlockHeaderRaw(
            blockHeaderRaw_
        );

        require(
            blockExists(blockHeader_.prevBlockHash),
            PrevBlockDoesNotExist(blockHeader_.prevBlockHash)
        );

        uint64 blockHeight_ = getBlockHeight(blockHeader_.prevBlockHash) + 1;
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

    /// @inheritdoc ISPVGateway
    function checkTxInclusion(
        bytes32[] calldata merkleProof_,
        bytes32 blockHash_,
        bytes32 txId_,
        uint256 txIndex_,
        uint256 minConfirmationsCount_
    ) external view returns (bool) {
        (bool isInMainchain_, uint256 confirmationsCount_) = getBlockStatus(blockHash_);

        if (!isInMainchain_ || confirmationsCount_ < minConfirmationsCount_) {
            return false;
        }

        bytes32 leRoot_ = getBlockMerkleRoot(blockHash_).bytes32BEtoLE();

        return TxMerkleProof.verify(merkleProof_, leRoot_, txId_, txIndex_);
    }

    /// @inheritdoc ISPVGateway
    function getMainchainHead() public view returns (bytes32) {
        return _getSPVGatewayStorage().mainchainHead;
    }

    /// @inheritdoc ISPVGateway
    function getMainchainHeight() public view returns (uint64) {
        return getBlockHeight(_getSPVGatewayStorage().mainchainHead);
    }

    /// @inheritdoc ISPVGateway
    function getBlockInfo(bytes32 blockHash_) external view returns (BlockInfo memory blockInfo_) {
        if (!blockExists(blockHash_)) {
            return blockInfo_;
        }

        BlockData memory blockData_ = _getSPVGatewayStorage().blocksData[blockHash_];

        blockInfo_ = BlockInfo({
            mainBlockData: blockData_,
            isInMainchain: isInMainchain(blockHash_),
            cumulativeWork: _getBlockCumulativeWork(blockData_.blockHeight, blockHash_)
        });
    }

    /// @inheritdoc ISPVGateway
    function getBlockHeader(
        bytes32 blockHash_
    ) public view returns (BlockHeader.HeaderData memory) {
        BlockData storage blockData = _getSPVGatewayStorage().blocksData[blockHash_];

        return
            BlockHeader.HeaderData({
                version: blockData.version,
                prevBlockHash: blockData.prevBlockHash,
                merkleRoot: blockData.merkleRoot,
                time: blockData.time,
                bits: blockData.bits,
                nonce: blockData.nonce
            });
    }

    /// @inheritdoc ISPVGateway
    function getBlockStatus(bytes32 blockHash_) public view returns (bool, uint64) {
        if (!isInMainchain(blockHash_)) {
            return (false, 0);
        }

        return (true, getMainchainHeight() - getBlockHeight(blockHash_));
    }

    /// @inheritdoc ISPVGateway
    function getBlockMerkleRoot(bytes32 blockHash_) public view returns (bytes32) {
        return _getSPVGatewayStorage().blocksData[blockHash_].merkleRoot;
    }

    /// @inheritdoc ISPVGateway
    function getBlockHeight(bytes32 blockHash_) public view returns (uint64) {
        return _getSPVGatewayStorage().blocksData[blockHash_].blockHeight;
    }

    /// @inheritdoc ISPVGateway
    function getBlockHash(uint64 blockHeight_) public view returns (bytes32) {
        return _getSPVGatewayStorage().blocksHeightToBlockHash[blockHeight_];
    }

    /// @inheritdoc ISPVGateway
    function getBlockTarget(bytes32 blockHash_) public view returns (bytes32) {
        return TargetsHelper.bitsToTarget(_getSPVGatewayStorage().blocksData[blockHash_].bits);
    }

    /// @inheritdoc ISPVGateway
    function getLastEpochCumulativeWork() public view returns (uint256) {
        return _getSPVGatewayStorage().lastEpochCumulativeWork;
    }

    /// @inheritdoc ISPVGateway
    function blockExists(bytes32 blockHash_) public view returns (bool) {
        return _getBlockHeaderTime(blockHash_) > 0;
    }

    /// @inheritdoc ISPVGateway
    function isInMainchain(bytes32 blockHash_) public view returns (bool) {
        return getBlockHash(getBlockHeight(blockHash_)) == blockHash_;
    }

    function _addBlock(
        BlockHeader.HeaderData memory blockHeader_,
        bytes32 blockHash_,
        uint64 blockHeight_
    ) internal {
        SPVGatewayStorage storage $ = _getSPVGatewayStorage();

        $.blocksData[blockHash_] = BlockData({
            prevBlockHash: blockHeader_.prevBlockHash,
            merkleRoot: blockHeader_.merkleRoot,
            version: blockHeader_.version,
            time: blockHeader_.time,
            nonce: blockHeader_.nonce,
            bits: blockHeader_.bits,
            blockHeight: blockHeight_
        });

        _updateMainchainHead(blockHeader_, blockHash_, blockHeight_);

        emit BlockHeaderAdded(blockHeight_, blockHash_);
    }

    function _updateMainchainHead(
        BlockHeader.HeaderData memory blockHeader_,
        bytes32 blockHash_,
        uint64 blockHeight_
    ) internal {
        SPVGatewayStorage storage $ = _getSPVGatewayStorage();

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
            uint64 prevBlockHeight_ = blockHeight_ - 1;

            do {
                $.blocksHeightToBlockHash[prevBlockHeight_] = prevBlockHash_;

                prevBlockHash_ = _getSPVGatewayStorage().blocksData[prevBlockHash_].prevBlockHash;

                unchecked {
                    --prevBlockHeight_;
                }
            } while (getBlockHash(prevBlockHeight_) != prevBlockHash_ && prevBlockHash_ != 0);
        }
    }

    function _updateLastEpochCumulativeWork(
        bytes32 currentTarget_,
        uint64 blockHeight_
    ) internal returns (bytes32) {
        SPVGatewayStorage storage $ = _getSPVGatewayStorage();

        if (TargetsHelper.isTargetAdjustmentBlock(blockHeight_)) {
            $.lastEpochCumulativeWork += TargetsHelper.countEpochCumulativeWork(currentTarget_);

            uint32 epochStartTime_ = _getBlockHeaderTime(
                getBlockHash(blockHeight_ - TargetsHelper.DIFFICULTY_ADJUSTMENT_INTERVAL)
            );
            uint32 epochEndTime_ = _getBlockHeaderTime(getBlockHash(blockHeight_ - 1));
            uint32 passedTime_ = epochEndTime_ - epochStartTime_;

            currentTarget_ = TargetsHelper.countNewRoundedTarget(currentTarget_, passedTime_);
        }

        return currentTarget_;
    }

    function _parseBlockHeadersRaw(
        bytes[] calldata blockHeaderRawArray_
    )
        internal
        view
        returns (BlockHeader.HeaderData[] memory blockHeaders_, bytes32[] memory blockHashes_)
    {
        require(blockHeaderRawArray_.length > 0, EmptyBlockHeaderArray());

        blockHeaders_ = new BlockHeader.HeaderData[](blockHeaderRawArray_.length);
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
    ) internal view returns (BlockHeader.HeaderData memory blockHeader_, bytes32 blockHash_) {
        (blockHeader_, blockHash_) = blockHeaderRaw_.parseBlockHeader(true);

        _onlyNonExistingBlock(blockHash_);
    }

    function _getStorageMedianTime(
        BlockHeader.HeaderData memory blockHeader_,
        uint64 blockHeight_
    ) internal view returns (uint32) {
        if (blockHeight_ == 1) {
            return blockHeader_.time;
        }

        bytes32 toBlockHash_ = blockHeader_.prevBlockHash;

        if (blockHeight_ - 1 < MEDIAN_PAST_BLOCKS) {
            return _getBlockHeaderTime(toBlockHash_);
        }

        uint256[] memory blocksTime_ = new uint256[](MEDIAN_PAST_BLOCKS);
        bool needsSort_;

        for (uint256 i = MEDIAN_PAST_BLOCKS; i > 0; --i) {
            uint32 currentTime_ = _getBlockHeaderTime(toBlockHash_);

            blocksTime_[i - 1] = currentTime_;
            toBlockHash_ = _getSPVGatewayStorage().blocksData[toBlockHash_].prevBlockHash;

            if (i < MEDIAN_PAST_BLOCKS && currentTime_ > blocksTime_[i]) {
                needsSort_ = true;
            }
        }

        return _getMedianTime(blocksTime_, needsSort_);
    }

    function _getMemoryMedianTime(
        BlockHeader.HeaderData[] memory blockHeaders_,
        uint64 to_
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
        uint64 blockHeight_,
        bytes32 blockHash_
    ) internal view returns (uint256) {
        uint256 currentEpochCumulativeWork_ = getBlockTarget(blockHash_).countCumulativeWork(
            TargetsHelper.getEpochBlockNumber(blockHeight_) + 1
        );

        return _getSPVGatewayStorage().lastEpochCumulativeWork + currentEpochCumulativeWork_;
    }

    function _getBlockHeaderTime(bytes32 blockHash_) internal view returns (uint32) {
        return _getSPVGatewayStorage().blocksData[blockHash_].time;
    }

    function _onlyNonExistingBlock(bytes32 blockHash_) internal view {
        require(!blockExists(blockHash_), BlockAlreadyExists(blockHash_));
    }

    function _validateBlockRules(
        BlockHeader.HeaderData memory blockHeader_,
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
