// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library TargetsHelper {
    /**
     * @notice Ideal expected target blocks time
     *
     * 2016 blocks of 10 minutes each
     */
    uint256 public constant EXPECTED_TARGET_BLOCKS_TIME = 1209600;

    bytes32 public constant INITIAL_TARGET =
        0x00000000ffff0000000000000000000000000000000000000000000000000000;

    uint256 public constant TARGET_FIXED_POINT_FACTOR = 10 ** 18;
    uint256 public constant MAX_TARGET_FACTOR = 4;

    uint256 public constant MAX_TARGET_RATIO = TARGET_FIXED_POINT_FACTOR * MAX_TARGET_FACTOR;
    uint256 public constant MIN_TARGET_RATIO = TARGET_FIXED_POINT_FACTOR / MAX_TARGET_FACTOR;

    function countNewRoundedTarget(
        bytes32 currentTarget_,
        uint256 actualPassedTime_
    ) internal pure returns (bytes32) {
        return roundTarget(countNewTarget(currentTarget_, actualPassedTime_));
    }

    function countNewTarget(
        bytes32 currentTarget_,
        uint256 actualPassedTime_
    ) internal pure returns (bytes32) {
        uint256 currentRatio = (actualPassedTime_ * TARGET_FIXED_POINT_FACTOR) /
            EXPECTED_TARGET_BLOCKS_TIME;

        currentRatio = Math.min(Math.max(currentRatio, MIN_TARGET_RATIO), MAX_TARGET_RATIO);

        bytes32 target_ = bytes32(
            Math.mulDiv(uint256(currentTarget_), currentRatio, TARGET_FIXED_POINT_FACTOR)
        );

        return target_ > INITIAL_TARGET ? target_ : INITIAL_TARGET;
    }

    function countBlockWork(bytes32 target_) internal pure returns (uint256 blockWork_) {
        assembly {
            blockWork_ := div(not(blockWork_), add(target_, 0x1))
        }
    }

    function bitsToTarget(bytes4 bits_) internal pure returns (bytes32 target_) {
        assembly {
            let targetShift := mul(sub(0x20, byte(0, bits_)), 0x8)

            target_ := shr(targetShift, shl(0x8, bits_))
        }
    }

    function targetToBits(bytes32 target_) internal pure returns (bytes4 bits_) {
        assembly {
            let coefficientLength := 0x3
            let coefficientStartIndex := 0

            let bitsPtr := mload(0x40)
            mstore(0x40, add(bitsPtr, 0x4))

            for {
                let i := 0
            } lt(i, 0x20) {
                i := add(i, 0x1)
            } {
                let currentByte := byte(i, target_)

                if gt(currentByte, 0) {
                    coefficientStartIndex := i

                    if gt(currentByte, 0x80) {
                        coefficientStartIndex := sub(coefficientStartIndex, 0x1)
                    }

                    break
                }
            }

            mstore8(bitsPtr, sub(0x20, coefficientStartIndex))

            for {
                let i := 0
            } lt(i, coefficientLength) {
                i := add(i, 0x1)
            } {
                mstore8(add(bitsPtr, add(i, 0x1)), byte(add(coefficientStartIndex, i), target_))
            }

            bits_ := mload(bitsPtr)
        }
    }

    function roundTarget(bytes32 currentTarget_) internal pure returns (bytes32 roundedTarget_) {
        assembly {
            let coefficientLength := 0x3
            let coefficientEndIndex := 0

            for {
                let i := 0
            } lt(i, 0x20) {
                i := add(i, 0x1)
            } {
                let currentByte := byte(i, currentTarget_)

                if gt(currentByte, 0) {
                    coefficientEndIndex := add(i, coefficientLength)

                    if gt(currentByte, 0x80) {
                        coefficientEndIndex := sub(coefficientEndIndex, 0x1)
                    }

                    break
                }
            }

            let keepBits := mul(sub(0x20, coefficientEndIndex), 8)
            let mask := not(sub(shl(keepBits, 1), 1))

            roundedTarget_ := and(currentTarget_, mask)
        }
    }
}
