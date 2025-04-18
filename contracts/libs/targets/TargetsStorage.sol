// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TargetsHelper} from "./TargetsHelper.sol";

library TargetsStorage {
    using TargetsHelper for bytes32;

    uint256 public constant DIFFICULTY_ADJSTMENT_INTERVAL = 2016;

    error InvalidEpochTimeParameters(uint32 epochStartTime_, uint32 epochEndTime_);
    error InvalidConfirmedBlockHash(bytes32 blockHash);
    error NotATargetAdjustmentBlock(uint256 blockHeight);
    error TargetsStorageAlreadyInitialized();
    error TargetsStorageNotInitialized();

    struct TargetsData {
        mapping(uint256 => bytes32) targets;
        mapping(bytes32 => bytes32) pendingBlockHashToTarget;
        uint256 lastTargetEpoch;
        uint256 pendingTargetEpoch;
    }

    modifier onlyInitialized(TargetsData storage self) {
        _onlyInitialized(self);
        _;
    }

    function initialize(TargetsData storage self) internal {
        _initialize(self, 0, TargetsHelper.INITIAL_TARGET);
    }

    function initialize(
        TargetsData storage self,
        uint256 startBlockHeight_,
        bytes32 startTarget_
    ) internal {
        _onlyTargetAdjustmentBlock(startBlockHeight_);

        _initialize(self, startBlockHeight_, startTarget_);
    }

    function confirmPendingTarget(
        TargetsData storage self,
        bytes32 confirmedBlockHash_
    ) internal onlyInitialized(self) {
        require(
            self.pendingBlockHashToTarget[confirmedBlockHash_] > 0,
            InvalidConfirmedBlockHash(confirmedBlockHash_)
        );

        uint256 pendingTargetEpoch_ = self.pendingTargetEpoch;

        self.lastTargetEpoch = pendingTargetEpoch_;
        self.targets[pendingTargetEpoch_] = self.pendingBlockHashToTarget[confirmedBlockHash_];

        delete self.pendingTargetEpoch;
        delete self.pendingBlockHashToTarget[confirmedBlockHash_];
    }

    function updatePendingTarget(
        TargetsData storage self,
        uint256 blockHeight_,
        bytes32 blockHash_,
        uint32 epochStartTime_,
        uint32 epochEndTime_
    ) internal onlyInitialized(self) {
        _onlyTargetAdjustmentBlock(blockHeight_);

        _updatePendingTarget(self, blockHeight_, blockHash_, epochStartTime_, epochEndTime_);
    }

    function getLastEpoch(TargetsData storage self) internal view returns (uint256) {
        return self.lastTargetEpoch;
    }

    function getPendingEpoch(TargetsData storage self) internal view returns (uint256) {
        return self.pendingTargetEpoch;
    }

    function getLastTarget(TargetsData storage self) internal view returns (bytes32) {
        return getTarget(self, self.lastTargetEpoch);
    }

    function getTargetByBlockHeight(
        TargetsData storage self,
        uint256 blockHeight_
    ) internal view returns (bytes32) {
        return getTarget(self, countTargetEpoch(blockHeight_));
    }

    function getPendingTarget(
        TargetsData storage self,
        bytes32 blockHash_
    ) internal view returns (bytes32) {
        return self.pendingBlockHashToTarget[blockHash_];
    }

    function getTarget(
        TargetsData storage self,
        uint256 targetEpoch_
    ) internal view returns (bytes32) {
        return self.targets[targetEpoch_];
    }

    function getPendingBlockWork(
        TargetsData storage self,
        bytes32 blockHash_
    ) internal view returns (uint256) {
        return getBlockWork(getPendingTarget(self, blockHash_));
    }

    function getBlockWorkByBlockHeight(
        TargetsData storage self,
        uint256 blockHeight_
    ) internal view returns (uint256) {
        return getBlockWork(getTargetByBlockHeight(self, blockHeight_));
    }

    function hasPendingTarget(TargetsData storage self) internal view returns (bool) {
        return self.pendingTargetEpoch > 0;
    }

    function getBlockWork(bytes32 target_) internal pure returns (uint256) {
        return target_.countBlockWork();
    }

    /**
     * @notice Function to count network target epoch number
     *
     * From 0 to 2016 -> 1st epoch
     * From 2017 to 4032 -> 2st epoch
     *
     * @param blockHeight_ The network block height value
     */
    function countTargetEpoch(uint256 blockHeight_) internal pure returns (uint256 targetEpoch_) {
        targetEpoch_ = blockHeight_ / DIFFICULTY_ADJSTMENT_INTERVAL + 1;

        if (isTargetAdjustmentBlock(blockHeight_)) {
            targetEpoch_--;
        }
    }

    function isTargetAdjustmentBlock(uint256 blockHeight_) internal pure returns (bool) {
        return getEpochBlockNumber(blockHeight_) == 0 && blockHeight_ > 0;
    }

    function getEpochBlockNumber(uint256 blockHeight_) internal pure returns (uint256) {
        return blockHeight_ % DIFFICULTY_ADJSTMENT_INTERVAL;
    }

    function _initialize(
        TargetsData storage self,
        uint256 startBlockHeight_,
        bytes32 startTarget_
    ) private {
        require(!_isInitialized(self), TargetsStorageAlreadyInitialized());

        uint256 startEpoch_ = countTargetEpoch(startBlockHeight_);

        self.targets[startEpoch_] = startTarget_;
        self.lastTargetEpoch = startEpoch_;
    }

    function _updatePendingTarget(
        TargetsData storage self,
        uint256 blockHeight_,
        bytes32 blockHash_,
        uint32 epochStartTime_,
        uint32 epochEndTime_
    ) private {
        require(
            epochEndTime_ > epochStartTime_,
            InvalidEpochTimeParameters(epochStartTime_, epochEndTime_)
        );

        uint256 nextTargetEpoch_ = countTargetEpoch(blockHeight_) + 1;
        bytes32 newTargetValue_ = getTarget(self, nextTargetEpoch_ - 1).countNewRoundedTarget(
            epochEndTime_ - epochStartTime_
        );

        self.pendingTargetEpoch = nextTargetEpoch_;
        self.pendingBlockHashToTarget[blockHash_] = newTargetValue_;
    }

    function _onlyInitialized(TargetsData storage self) private view {
        require(_isInitialized(self), TargetsStorageNotInitialized());
    }

    function _isInitialized(TargetsData storage self) private view returns (bool) {
        return self.lastTargetEpoch > 0;
    }

    function _onlyTargetAdjustmentBlock(uint256 blockHeight_) private pure {
        require(isTargetAdjustmentBlock(blockHeight_), NotATargetAdjustmentBlock(blockHeight_));
    }
}
