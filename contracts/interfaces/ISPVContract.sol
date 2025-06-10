// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BlockHeaderData} from "../libs/BlockHeader.sol";

interface ISPVContract {
    error InvalidInitialBlockHeight(uint256 blockHeight);
    error PrevBlockDoesNotExist(bytes32 prevBlockHash);
    error BlockAlreadyExists(bytes32 blockHash);

    error EmptyBlockHeaderArray();
    error InvalidBlockHeadersOrder();

    error InvalidTarget(bytes32 blockTarget, bytes32 networkTarget);
    error InvalidBlockHash(bytes32 actualBlockHash, bytes32 blockTarget);
    error InvalidBlockTime(uint32 blockTime, uint32 medianTime);

    event MainchainHeadUpdated(
        uint256 indexed newMainchainHeight,
        bytes32 indexed newMainchainHead
    );
    event BlockHeaderAdded(uint256 indexed blockHeight, bytes32 indexed blockHash);

    struct BlockData {
        BlockHeaderData header;
        uint256 blockHeight;
    }

    struct BlockInfo {
        BlockData mainBlockData;
        bool isInMainchain;
        uint256 cumulativeWork;
    }

    function addBlockHeaderBatch(bytes[] calldata blockHeaderRawArray_) external;

    function addBlockHeader(bytes calldata blockHeaderRaw_) external;

    function getLastEpochCumulativeWork() external view returns (uint256);

    function getBlockMerkleRoot(bytes32 blockHash_) external view returns (bytes32);

    function getBlockInfo(bytes32 blockHash_) external view returns (BlockInfo memory blockInfo_);

    function getBlockData(bytes32 blockHash_) external view returns (BlockData memory);

    function getMainchainHead() external view returns (bytes32);

    function getBlockHeight(bytes32 blockHash_) external view returns (uint256);

    function getBlockHash(uint256 blockHeight_) external view returns (bytes32);

    function getBlockTarget(bytes32 blockHash_) external view returns (bytes32);

    function blockExists(bytes32 blockHash_) external view returns (bool);

    function getMainchainBlockHeight() external view returns (uint256);

    function isInMainchain(bytes32 blockHash_) external view returns (bool);
}
