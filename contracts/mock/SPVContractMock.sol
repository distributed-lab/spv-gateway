// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BlockHeader, BlockHeaderData} from "../libs/BlockHeader.sol";

import {SPVContract} from "../SPVContract.sol";

contract SPVContractMock is SPVContract {
    using BlockHeader for bytes;

    function getStorageMedianTime(
        bytes calldata blockHeaderRaw_,
        uint256 blockHeight_
    ) external view returns (uint32) {
        (BlockHeaderData memory blockHeader_, ) = blockHeaderRaw_.parseBlockHeaderData();

        return _getStorageMedianTime(blockHeader_, blockHeight_);
    }

    function getMemoryMedianTime(
        bytes[] calldata blockHeaderRawArr_,
        uint256 to_
    ) external pure returns (uint32) {
        BlockHeaderData[] memory blockHeaders_ = new BlockHeaderData[](blockHeaderRawArr_.length);

        for (uint256 i = 0; i < blockHeaderRawArr_.length; i++) {
            (blockHeaders_[i], ) = blockHeaderRawArr_[i].parseBlockHeaderData();
        }

        return _getMemoryMedianTime(blockHeaders_, to_);
    }

    function validateBlockRules(
        BlockHeaderData memory blockHeader_,
        bytes32 blockHash_,
        bytes32 target_,
        uint32 medianTime_
    ) external pure {
        _validateBlockRules(blockHeader_, blockHash_, target_, medianTime_);
    }
}
