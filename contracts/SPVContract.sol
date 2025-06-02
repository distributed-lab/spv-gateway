// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {LibSort} from "solady/src/utils/LibSort.sol";

import {BlockHeader, BlockHeaderData} from "./libs/BlockHeader.sol";
import {TargetsHelper} from "./libs/TargetsHelper.sol";

import {ISPVContract} from "./interfaces/ISPVContract.sol";

contract SPVContract is ISPVContract, Initializable {
    using EnumerableSet for EnumerableSet.Bytes32Set;
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
    }

    function _getSPVContractStorage() private pure returns (SPVContractStorage storage _spvs) {
        bytes32 slot_ = SPV_CONTRACT_STORAGE_SLOT;

        assembly {
            _spvs.slot := slot_
        }
    }

    function addBlockHeader(bytes calldata blockHeaderRaw_) external {
        SPVContractStorage storage $ = _getSPVContractStorage();

        (BlockHeaderData memory blockHeader_, bytes32 blockHash_) = blockHeaderRaw_
            .parseBlockHeaderData();

        require(!blockExists(blockHash_), BlockAlreadyExists(blockHash_));
        require(
            blockExists(blockHeader_.prevBlockHash),
            PrevBlockDoesNotExist(blockHeader_.prevBlockHash)
        );

        uint256 blockHeight_ = $.blocksData[blockHeader_.prevBlockHash].blockHeight + 1;
        bytes32 currentTarget_ = getBlockTarget(blockHeader_.prevBlockHash);

        if (TargetsHelper.isTargetAdjustmentBlock(blockHeight_)) {
            $.lastEpochCumulativeWork += TargetsHelper.countEpochCumulativeWork(currentTarget_);

            uint256 passedTime_ = blockHeader_.time -
                getBlockTimeByBlockHeight(
                    blockHeight_ - TargetsHelper.DIFFICULTY_ADJUSTMENT_INTERVAL
                );
            currentTarget_ = TargetsHelper.countNewRoundedTarget(currentTarget_, passedTime_);
        }

        _validateBlockRules(
            blockHeader_,
            blockHash_,
            currentTarget_,
            getMedianTime(blockHeader_.prevBlockHash)
        );

        _addBlock(blockHeader_, blockHash_, blockHeight_);

        emit BlockHeaderAdded(blockHeight_, blockHash_);
    }

    function getMainchainHead() external view returns (bytes32) {
        return _getSPVContractStorage().mainchainHead;
    }

    function getBlockHeight(bytes32 blockHash_) external view returns (uint256) {
        return _getSPVContractStorage().blocksData[blockHash_].blockHeight;
    }

    function getBlockHash(uint256 blockHeight_) external view returns (bytes32) {
        return _getSPVContractStorage().blocksHeightToBlockHash[blockHeight_];
    }

    function getBlockTimeByBlockHeight(uint256 blockHeight_) public view returns (uint32) {
        SPVContractStorage storage $ = _getSPVContractStorage();

        return $.blocksData[$.blocksHeightToBlockHash[blockHeight_]].header.time;
    }

    function getBlockTarget(bytes32 blockHash_) public view returns (bytes32) {
        return
            TargetsHelper.bitsToTarget(
                _getSPVContractStorage().blocksData[blockHash_].header.bits
            );
    }

    function blockExists(bytes32 blockHash_) public view returns (bool) {
        return _getSPVContractStorage().blocksData[blockHash_].header.time > 0;
    }

    function getMainchainBlockHeight() public view returns (uint256) {
        SPVContractStorage storage $ = _getSPVContractStorage();

        return $.blocksData[$.mainchainHead].blockHeight;
    }

    function getMedianTime(bytes32 toBlockHash_) public view returns (uint32) {
        SPVContractStorage storage $ = _getSPVContractStorage();
        uint256 blockHeight_ = $.blocksData[toBlockHash_].blockHeight;

        if (blockHeight_ <= MEDIAN_PAST_BLOCKS || getMainchainBlockHeight() < MEDIAN_PAST_BLOCKS) {
            return 0;
        }

        uint256[] memory blocksTime_ = new uint256[](MEDIAN_PAST_BLOCKS);
        uint256 blocksTimeIndex_ = MEDIAN_PAST_BLOCKS;

        for (uint256 i = blockHeight_ - MEDIAN_PAST_BLOCKS; i < blockHeight_; ++i) {
            blocksTime_[--blocksTimeIndex_] = $.blocksData[toBlockHash_].header.time;

            toBlockHash_ = $.blocksData[toBlockHash_].header.prevBlockHash;
        }

        LibSort.insertionSort(blocksTime_);

        return uint32(blocksTime_[MEDIAN_PAST_BLOCKS / 2]);
    }

    function isInMainchain(bytes32 blockHash_) public view returns (bool) {
        SPVContractStorage storage $ = _getSPVContractStorage();

        return $.blocksHeightToBlockHash[$.blocksData[blockHash_].blockHeight] == blockHash_;
    }

    function _addBlock(
        BlockHeaderData memory blockHeader_,
        bytes32 blockHash_,
        uint256 blockHeight_
    ) internal {
        SPVContractStorage storage $ = _getSPVContractStorage();

        $.blocksData[blockHash_] = BlockData({header: blockHeader_, blockHeight: blockHeight_});

        _updateMainchainHead(blockHeader_, blockHash_, blockHeight_);
    }

    function _updateMainchainHead(
        BlockHeaderData memory blockHeader_,
        bytes32 blockHash_,
        uint256 blockHeight_
    ) internal {
        SPVContractStorage storage $ = _getSPVContractStorage();

        bytes32 mainchainHead = $.mainchainHead;

        if (blockHeader_.prevBlockHash == mainchainHead) {
            $.mainchainHead = blockHash_;
            $.blocksHeightToBlockHash[blockHeight_] = blockHash_;

            return;
        }

        uint256 mainchainCumulativeWork_ = _getBlockCumulativeWork(
            $.blocksData[mainchainHead].blockHeight,
            getBlockTarget(mainchainHead)
        );
        uint256 newBlockCumulativeWork_ = _getBlockCumulativeWork(
            blockHeight_,
            getBlockTarget(blockHash_)
        );

        if (newBlockCumulativeWork_ > mainchainCumulativeWork_) {
            $.mainchainHead = blockHash_;
            $.blocksHeightToBlockHash[blockHeight_] = blockHash_;

            bytes32 prevBlockHash_ = blockHeader_.prevBlockHash;
            uint256 prevBlockHeight_ = blockHeight_ - 1;
            while (true) {
                if (
                    $.blocksHeightToBlockHash[prevBlockHeight_] == prevBlockHash_ ||
                    prevBlockHash_ == 0
                ) {
                    break;
                }

                $.blocksHeightToBlockHash[prevBlockHeight_] = prevBlockHash_;

                prevBlockHash_ = $.blocksData[prevBlockHash_].header.prevBlockHash;
                prevBlockHeight_ -= 1;
            }
        }
    }

    function _getBlockCumulativeWork(
        uint256 blockHeight_,
        bytes32 target_
    ) internal view returns (uint256) {
        uint256 currentEpochCumulativeWork_ = target_.countCumulativeWork(
            TargetsHelper.getEpochBlockNumber(blockHeight_) + 1
        );

        return _getSPVContractStorage().lastEpochCumulativeWork + currentEpochCumulativeWork_;
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
        require(blockHeader_.time > medianTime_, InvalidBlockTime(blockHeader_.time, medianTime_));
    }
}
