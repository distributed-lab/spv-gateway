// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TargetsHelper} from "../../libs/TargetsHelper.sol";

contract TargetsHelperMock {
    using TargetsHelper for bytes32;

    function countNewRoundedTarget(
        bytes32 currentTarget_,
        uint32 actualPassedTime_
    ) external pure returns (bytes32) {
        return currentTarget_.countNewRoundedTarget(actualPassedTime_);
    }

    function countNewTarget(
        bytes32 currentTarget_,
        uint32 actualPassedTime_
    ) external pure returns (bytes32) {
        return currentTarget_.countNewTarget(actualPassedTime_);
    }

    function countBlockWork(bytes32 target_) external pure returns (uint256) {
        return target_.countBlockWork();
    }

    function bitsToTarget(bytes4 bits_) external pure returns (bytes32) {
        return TargetsHelper.bitsToTarget(bits_);
    }

    function targetToBits(bytes32 target_) external pure returns (bytes4) {
        return target_.targetToBits();
    }

    function roundTarget(bytes32 currentTarget_) external pure returns (bytes32) {
        return currentTarget_.roundTarget();
    }
}
