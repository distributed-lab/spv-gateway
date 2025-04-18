// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {BlockHeader, BlockHeaderData} from "./libs/BlockHeader.sol";
import {BlocksStorage} from "./libs/BlocksStorage.sol";
import {TargetsStorage} from "./libs/targets/TargetsStorage.sol";
import {TargetsHelper} from "./libs/targets/TargetsHelper.sol";

// import "hardhat/console.sol";

contract SPVContract is Initializable {
    using BlockHeader for bytes;
    using BlocksStorage for BlocksStorage.BlocksData;
    using TargetsStorage for TargetsStorage.TargetsData;

    bytes32 public constant SPV_CONTRACT_STORAGE_SLOT =
        keccak256("spv.contract.spv.contract.storage");

    error PrevBlockDoesNotExist(bytes32 prevBlockHash);
    error BlockAlreadyExists(bytes32 blockHash);

    error InvalidTarget(bytes32 blockTarget, bytes32 networkTarget);
    error InvalidBlockHash(bytes32 actualBlockHash, bytes32 blockTarget);
    error InvalidBlockTime(uint32 blockTime, uint32 medianTime);

    event BlockHeaderAdded(uint256 indexed blockHeight, bytes32 indexed blockHash);

    struct SPVContractStorage {
        BlocksStorage.BlocksData blocksData;
        TargetsStorage.TargetsData targets;
        uint256 pendingTargetHeightCount;
    }

    function __SPVContract_init(
        uint256 pendingBlockCount_,
        uint256 pendingTargetHeightCount_
    ) external initializer {
        SPVContractStorage storage $ = _getSPVContractStorage();

        $.blocksData.initialize(pendingBlockCount_);
        $.targets.initialize();

        $.pendingTargetHeightCount = pendingTargetHeightCount_;
    }

    function _getSPVContractStorage() internal pure returns (SPVContractStorage storage _spvs) {
        bytes32 slot_ = SPV_CONTRACT_STORAGE_SLOT;

        assembly {
            _spvs.slot := slot_
        }
    }

    function addBlockHeader(bytes calldata blockHeaderRaw_) external {
        SPVContractStorage storage $ = _getSPVContractStorage();

        (BlockHeaderData memory blockHeader_, bytes32 blockHash_) = blockHeaderRaw_
            .parseBlockHeaderData();

        // console.logBytes32(blockHash_);

        require(!$.blocksData.blockExists(blockHash_), BlockAlreadyExists(blockHash_));
        require(
            $.blocksData.blockExists(blockHeader_.prevBlockHash),
            PrevBlockDoesNotExist(blockHeader_.prevBlockHash)
        );

        uint256 blockHeight_ = $.blocksData.getBlockHeight(blockHeader_.prevBlockHash) + 1;

        _tryConfirmPendingTarget(blockHeight_);

        bytes32 target_ = _getRequiredTarget(blockHeight_, blockHeader_.prevBlockHash);

        _validateBlockRules(blockHeader_, blockHash_, target_);

        $.blocksData.addBlock(
            blockHeader_,
            blockHash_,
            blockHeight_,
            TargetsStorage.getBlockWork(target_)
        );

        if (TargetsStorage.isTargetAdjustmentBlock(blockHeight_)) {
            $.targets.updatePendingTarget(
                blockHeight_,
                blockHash_,
                $.blocksData.getBlockTimeByBlockHeight(
                    blockHeight_ - TargetsStorage.DIFFICULTY_ADJSTMENT_INTERVAL
                ),
                blockHeader_.time
            );
        }

        emit BlockHeaderAdded(blockHeight_, blockHash_);
    }

    function _getRequiredTarget(
        uint256 blockHeight_,
        bytes32 prevBlockHash_
    ) internal view returns (bytes32 target_) {
        SPVContractStorage storage $ = _getSPVContractStorage();

        uint256 blockTargetEpoch_ = TargetsStorage.countTargetEpoch(blockHeight_);
        bool isPendingTargetRequired_ = blockTargetEpoch_ == $.targets.getPendingEpoch();

        if (isPendingTargetRequired_) {
            uint256 epochBlockNumber_ = TargetsStorage.getEpochBlockNumber(blockHeight_);

            for (uint256 i = 0; i < epochBlockNumber_ - 1; ++i) {
                prevBlockHash_ = $.blocksData.getPrevBlockHash(prevBlockHash_);
            }

            target_ = $.targets.getPendingTarget(prevBlockHash_);
        } else {
            target_ = $.targets.getTarget(blockTargetEpoch_);
        }

        assert(target_ > 0);
    }

    function _tryConfirmPendingTarget(uint256 blockHeight_) internal {
        SPVContractStorage storage $ = _getSPVContractStorage();

        if (!$.targets.hasPendingTarget() || blockHeight_ < $.pendingTargetHeightCount) {
            return;
        }

        uint256 lastActiveBlockHeight_ = blockHeight_ - $.pendingTargetHeightCount;

        if (TargetsStorage.isTargetAdjustmentBlock(lastActiveBlockHeight_)) {
            $.targets.confirmPendingTarget(
                $.blocksData.getBlockHashByBlockHeight(lastActiveBlockHeight_)
            );
        }
    }

    function _validateBlockRules(
        BlockHeaderData memory blockHeader_,
        bytes32 blockHash_,
        bytes32 target_
    ) internal view {
        SPVContractStorage storage $ = _getSPVContractStorage();

        bytes32 blockTarget_ = TargetsHelper.bitsToTarget(blockHeader_.bits);

        require(target_ == blockTarget_, InvalidTarget(blockTarget_, target_));
        require(blockHash_ <= blockTarget_, InvalidBlockHash(blockHash_, blockTarget_));

        uint32 medianTime_ = $.blocksData.getMedianTime(blockHeader_.prevBlockHash);

        require(blockHeader_.time > medianTime_, InvalidBlockTime(blockHeader_.time, medianTime_));
    }

    // function test(bytes calldata blockHeaderRaw_) external {
    //     BlockHeader.BlockHeaderData memory initBlockHeaderData_ = BlockHeader.parseBlockHeaderData(
    //         blockHeaderRaw_
    //     );

    //     console.logBytes32(initBlockHeaderData_.blockHash);
    // }
}
