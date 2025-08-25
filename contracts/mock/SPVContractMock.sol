// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BlockHeader} from "@solarity/solidity-lib/libs/bitcoin/BlockHeader.sol";

import {SPVContract} from "../SPVContract.sol";

contract SPVContractMock is SPVContract {
    using BlockHeader for bytes;

    function __SPVContractMock_init(bytes calldata blockHeaderRaw_) external initializer {
        (
            BlockHeader.HeaderData memory genesisBlockHeader_,
            bytes32 genesisBlockHash_
        ) = blockHeaderRaw_.parseBlockHeader(true);

        _addBlock(genesisBlockHeader_, genesisBlockHash_, 0);

        emit MainchainHeadUpdated(0, genesisBlockHash_);
    }

    function getStorageMedianTime(
        bytes calldata blockHeaderRaw_,
        uint64 blockHeight_
    ) external view returns (uint32) {
        (BlockHeader.HeaderData memory blockHeader_, ) = blockHeaderRaw_.parseBlockHeader(true);

        return _getStorageMedianTime(blockHeader_, blockHeight_);
    }

    function getMemoryMedianTime(
        bytes[] calldata blockHeaderRawArr_,
        uint64 to_
    ) external pure returns (uint32) {
        BlockHeader.HeaderData[] memory blockHeaders_ = new BlockHeader.HeaderData[](
            blockHeaderRawArr_.length
        );

        for (uint256 i = 0; i < blockHeaderRawArr_.length; ++i) {
            (blockHeaders_[i], ) = blockHeaderRawArr_[i].parseBlockHeader(true);
        }

        return _getMemoryMedianTime(blockHeaders_, to_);
    }

    function validateBlockRules(
        BlockHeader.HeaderData calldata blockHeader_,
        bytes32 blockHash_,
        bytes32 target_,
        uint32 medianTime_
    ) external pure {
        _validateBlockRules(blockHeader_, blockHash_, target_, medianTime_);
    }
}
