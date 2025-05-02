// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TargetsStorage} from "../../../libs/targets/TargetsStorage.sol";

contract TargetsStorageMock {
    using TargetsStorage for TargetsStorage.TargetsData;

    TargetsStorage.TargetsData internal _targetsData;

    function initialize() external {
        _targetsData.initialize();
    }

    function initialize(uint256 startBlockHeight_, bytes32 startTarget_) external {
        _targetsData.initialize(startBlockHeight_, startTarget_);
    }

    function confirmPendingTarget(bytes32 confirmedBlockHash_) external {
        _targetsData.confirmPendingTarget(confirmedBlockHash_);
    }

    function updatePendingTarget(
        uint256 blockHeight_,
        bytes32 blockHash_,
        uint32 epochStartTime_,
        uint32 epochEndTime_
    ) external {
        _targetsData.updatePendingTarget(blockHeight_, blockHash_, epochStartTime_, epochEndTime_);
    }

    function getLastEpoch() external view returns (uint256) {
        return _targetsData.getLastEpoch();
    }

    function getPendingEpoch() external view returns (uint256) {
        return _targetsData.getPendingEpoch();
    }

    function getLastTarget() external view returns (bytes32) {
        return _targetsData.getLastTarget();
    }

    function getTargetByBlockHeight(uint256 blockHeight_) external view returns (bytes32) {
        return _targetsData.getTargetByBlockHeight(blockHeight_);
    }

    function getPendingTarget(bytes32 blockHash_) external view returns (bytes32) {
        return _targetsData.getPendingTarget(blockHash_);
    }

    function getTarget(uint256 targetEpoch_) external view returns (bytes32) {
        return _targetsData.getTarget(targetEpoch_);
    }

    function getPendingBlockWork(bytes32 blockHash_) external view returns (uint256) {
        return _targetsData.getPendingBlockWork(blockHash_);
    }

    function getBlockWorkByBlockHeight(uint256 blockHeight_) external view returns (uint256) {
        return _targetsData.getBlockWorkByBlockHeight(blockHeight_);
    }

    function hasPendingTarget() external view returns (bool) {
        return _targetsData.hasPendingTarget();
    }

    function getBlockWork(bytes32 target_) external pure returns (uint256) {
        return TargetsStorage.getBlockWork(target_);
    }

    function countTargetEpoch(uint256 blockHeight_) external pure returns (uint256 targetEpoch_) {
        return TargetsStorage.countTargetEpoch(blockHeight_);
    }

    function isTargetAdjustmentBlock(uint256 blockHeight_) external pure returns (bool) {
        return TargetsStorage.isTargetAdjustmentBlock(blockHeight_);
    }

    function getEpochBlockNumber(uint256 blockHeight_) external pure returns (uint256) {
        return TargetsStorage.getEpochBlockNumber(blockHeight_);
    }
}
