// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BlockHeader, BlockHeaderData} from "../../libs/BlockHeader.sol";

contract BlockHeaderMock {
    using BlockHeader for bytes;

    function getBlockHeaderHash(bytes calldata blockHeaderRaw_) external pure returns (bytes32) {
        return blockHeaderRaw_.getBlockHeaderHash();
    }

    function parseBlockHeaderData(
        bytes calldata blockHeaderRaw_
    ) external pure returns (BlockHeaderData memory, bytes32) {
        return blockHeaderRaw_.parseBlockHeaderData();
    }

    function toRawBytes(BlockHeaderData memory headerData_) external pure returns (bytes memory) {
        return BlockHeader.toRawBytes(headerData_);
    }
}
