// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {SPVContract} from "../SPVContract.sol";

import {BlocksStorage} from "../libs/BlocksStorage.sol";
import {TargetsStorage} from "../libs/targets/TargetsStorage.sol";

contract SPVContractMock is SPVContract {
    using BlocksStorage for BlocksStorage.BlocksData;
    using TargetsStorage for TargetsStorage.TargetsData;

    function hasPendingTarget() external view returns (bool) {
        return _getSPVContractStorage().targets.hasPendingTarget();
    }

    function getLastEpoch() external view returns (uint256) {
        return _getSPVContractStorage().targets.getLastEpoch();
    }

    function getPendingEpoch() external view returns (uint256) {
        return _getSPVContractStorage().targets.getPendingEpoch();
    }

    function getLastTarget() external view returns (bytes32) {
        return _getSPVContractStorage().targets.getLastTarget();
    }

    function getPendingTarget(bytes32 blockHash_) external view returns (bytes32) {
        return _getSPVContractStorage().targets.getPendingTarget(blockHash_);
    }

    function getTarget(uint256 targetEpoch_) external view returns (bytes32) {
        return _getSPVContractStorage().targets.getTarget(targetEpoch_);
    }

    function getNextMainchainBlock(bytes32 blockHash_) external view returns (bytes32) {
        return _getSPVContractStorage().blocksData.getNextMainchainBlock(blockHash_);
    }

    function isInMainchain(bytes32 blockHash_) external view returns (bool) {
        return _getSPVContractStorage().blocksData.isInMainchain(blockHash_);
    }
}
