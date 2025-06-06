// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibBit} from "solady/src/utils/LibBit.sol";

struct BlockHeaderData {
    bytes32 prevBlockHash;
    bytes32 merkleRoot;
    uint32 version;
    uint32 time;
    uint32 nonce;
    bytes4 bits;
}

library BlockHeader {
    using LibBit for uint256;

    uint256 public constant BLOCK_HEADER_DATA_LENGTH = 80;

    error InvalidBlockHeaderDataLength();

    function getBlockHeaderHash(bytes calldata blockHeaderRaw_) internal pure returns (bytes32) {
        bytes32 rawBlockHash_ = sha256(abi.encode(sha256(blockHeaderRaw_)));

        return _reverseHash(rawBlockHash_);
    }

    function parseBlockHeaderData(
        bytes calldata blockHeaderRaw_
    ) internal pure returns (BlockHeaderData memory headerData_, bytes32 blockHash_) {
        require(
            blockHeaderRaw_.length == BLOCK_HEADER_DATA_LENGTH,
            InvalidBlockHeaderDataLength()
        );

        headerData_ = BlockHeaderData({
            version: uint32(_reverseBytes(blockHeaderRaw_[0:4])),
            prevBlockHash: _reverseHash(bytes32(blockHeaderRaw_[4:36])),
            merkleRoot: _reverseHash(bytes32(blockHeaderRaw_[36:68])),
            time: uint32(_reverseBytes(blockHeaderRaw_[68:72])),
            bits: bytes4(uint32(_reverseBytes(blockHeaderRaw_[72:76]))),
            nonce: uint32(_reverseBytes(blockHeaderRaw_[76:80]))
        });
        blockHash_ = getBlockHeaderHash(blockHeaderRaw_);
    }

    function toRawBytes(BlockHeaderData memory headerData_) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                _reverseUint32(headerData_.version),
                _reverseHash(headerData_.prevBlockHash),
                _reverseHash(headerData_.merkleRoot),
                _reverseUint32(headerData_.time),
                _reverseUint32(uint32(headerData_.bits)),
                _reverseUint32(headerData_.nonce)
            );
    }

    function _reverseHash(bytes32 blockHash_) private pure returns (bytes32) {
        return bytes32(uint256(blockHash_).reverseBytes());
    }

    function _reverseBytes(bytes calldata bytesToConvert_) private pure returns (uint256) {
        return uint256(bytes32(bytesToConvert_)).reverseBytes();
    }

    function _reverseUint32(uint32 input_) private pure returns (uint32) {
        return
            ((input_ & 0x000000FF) << 24) |
            ((input_ & 0x0000FF00) << 8) |
            ((input_ & 0x00FF0000) >> 8) |
            ((input_ & 0xFF000000) >> 24);
    }
}
