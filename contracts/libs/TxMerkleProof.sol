// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @notice A library for verifying transaction inclusion in Bitcoin block.
 * Provides functions for processing and verifying Merkle tree proofs
 */
library TxMerkleProof {
    error InvalidLengths();

    function verify(
        bytes32[] memory proof_,
        bytes calldata directions_,
        bytes32 root_,
        bytes32 leaf_
    ) internal pure returns (bool) {
        require(directions_.length == proof_.length, InvalidLengths());

        return processProof(proof_, directions_, leaf_) == root_;
    }

    function processProof(
        bytes32[] memory proof_,
        bytes calldata directions_,
        bytes32 leaf_
    ) internal pure returns (bytes32) {
        bytes32 computedHash_ = leaf_;
        uint256 proofLength_ = proof_.length;

        for (uint256 i = 0; i < proofLength_; ++i) {
            if (directions_[i] == hex"00") {
                computedHash_ = _sha256(computedHash_, proof_[i]);
            } else if (directions_[i] == hex"01") {
                computedHash_ = _sha256(proof_[i], computedHash_);
            } else {
                computedHash_ = _sha256(computedHash_, computedHash_);
            }
        }

        return computedHash_;
    }

    function _sha256(bytes32 left_, bytes32 right_) private pure returns (bytes32) {
        return sha256(abi.encodePacked(sha256(abi.encodePacked(left_, right_))));
    }
}
