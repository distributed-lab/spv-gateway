// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TargetsHelper} from "../../libs/TargetsHelper.sol";

/**
 * @notice Mock contract to expose TargetsHelper library functions for formal verification
 * This contract makes all internal library functions accessible for testing
 */
contract TargetsHelperMock {
    using TargetsHelper for *;

    function EXPECTED_TARGET_BLOCKS_TIME() external pure returns (uint256) {
        return TargetsHelper.EXPECTED_TARGET_BLOCKS_TIME;
    }

    function DIFFICULTY_ADJUSTMENT_INTERVAL() external pure returns (uint256) {
        return TargetsHelper.DIFFICULTY_ADJUSTMENT_INTERVAL;
    }

    function INITIAL_TARGET() external pure returns (bytes32) {
        return TargetsHelper.INITIAL_TARGET;
    }

    function TARGET_FIXED_POINT_FACTOR() external pure returns (uint256) {
        return TargetsHelper.TARGET_FIXED_POINT_FACTOR;
    }

    function MAX_TARGET_FACTOR() external pure returns (uint256) {
        return TargetsHelper.MAX_TARGET_FACTOR;
    }

    function MAX_TARGET_RATIO() external pure returns (uint256) {
        return TargetsHelper.MAX_TARGET_RATIO;
    }

    function MIN_TARGET_RATIO() external pure returns (uint256) {
        return TargetsHelper.MIN_TARGET_RATIO;
    }

    function isTargetAdjustmentBlock(uint256 blockHeight_) external pure returns (bool) {
        return TargetsHelper.isTargetAdjustmentBlock(blockHeight_);
    }

    function getEpochBlockNumber(uint256 blockHeight_) external pure returns (uint256) {
        return TargetsHelper.getEpochBlockNumber(blockHeight_);
    }

    function countNewRoundedTarget(
        bytes32 currentTarget_,
        uint256 actualPassedTime_
    ) external pure returns (bytes32) {
        return currentTarget_.countNewRoundedTarget(actualPassedTime_);
    }

    function countNewTarget(
        bytes32 currentTarget_,
        uint256 actualPassedTime_
    ) external pure returns (bytes32) {
        return currentTarget_.countNewTarget(actualPassedTime_);
    }

    function countEpochCumulativeWork(bytes32 epochTarget_) external pure returns (uint256) {
        return epochTarget_.countEpochCumulativeWork();
    }

    function countCumulativeWork(
        bytes32 epochTarget_,
        uint256 blocksCount_
    ) external pure returns (uint256) {
        return epochTarget_.countCumulativeWork(blocksCount_);
    }

    function countBlockWork(bytes32 target_) external pure returns (uint256) {
        return target_.countBlockWork();
    }

    function bitsToTarget(bytes4 bits_) external pure returns (bytes32) {
        return bits_.bitsToTarget();
    }

    // Reference implementation for bitsToTarget
    // Based on Bitcoin documentation: https://learnmeabitcoin.com/technical/block/bits/
    function bitsToTargetReference(bytes4 bits_) external pure returns (bytes32) {
        uint256 exponent_ = uint256(uint32(bits_)) >> 24;
        uint256 coefficient_ = uint256(uint32(bits_)) & 0xFFFFFF;

        if (exponent_ <= 3) {
            return bytes32(coefficient_ >> (8 * (3 - exponent_)));
        } else {
            return bytes32(coefficient_ << (8 * (exponent_ - 3)));
        }
    }

    function targetToBits(bytes32 target_) external pure returns (bytes4) {
        return target_.targetToBits();
    }

    // Reference implementation for targetToBits
    // Based on Bitcoin documentation: https://learnmeabitcoin.com/technical/block/bits/
    function targetToBitsReference(bytes32 target_) external pure returns (bytes4) {
        if (target_ == 0) {
            return bytes4(0);
        }

        uint256 targetValue_ = uint256(target_);

        // Find the most significant byte position
        uint256 byteLength_ = 0;
        uint256 temp = targetValue_;
        while (temp > 0) {
            byteLength_++;
            temp >>= 8;
        }

        // Extract coefficient (3 bytes)
        uint256 coefficient_;
        uint256 exponent_ = byteLength_;

        if (byteLength_ <= 3) {
            coefficient_ = targetValue_ << (8 * (3 - byteLength_));
            exponent_ = 3;
        } else {
            coefficient_ = targetValue_ >> (8 * (byteLength_ - 3));

            // If the coefficient's most significant bit is set, we need to add padding
            if (coefficient_ & 0x800000 != 0) {
                coefficient_ >>= 8;
                exponent_++;
            }
        }

        // Combine exponent and coefficient into bits format
        return bytes4((uint32(exponent_) << 24) | (uint32(coefficient_) & 0xFFFFFF));
    }

    function roundTarget(bytes32 currentTarget_) external pure returns (bytes32) {
        return currentTarget_.roundTarget();
    }

    // Additional helper functions for verification
    function isValidTarget(bytes32 target_) external pure returns (bool) {
        return target_ > 0 && target_ <= TargetsHelper.INITIAL_TARGET;
    }

    function isValidBits(bytes4 bits_) external pure returns (bool) {
        bytes32 target = TargetsHelper.bitsToTarget(bits_);
        return target > 0 && target <= TargetsHelper.INITIAL_TARGET;
    }
}
