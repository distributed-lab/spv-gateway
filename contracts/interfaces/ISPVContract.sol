// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {BlockHeaderData} from "../libs/BlockHeader.sol";

interface ISPVContract {
    error PrevBlockDoesNotExist(bytes32 prevBlockHash);
    error InvalidBlocksOrder();
    error BlockAlreadyExists(bytes32 blockHash);

    error InvalidNewBlockHeight(uint256 currentHeight, uint256 passedHeight);
    error InvalidTarget(bytes32 blockTarget, bytes32 networkTarget);
    error InvalidBlockHash(bytes32 actualBlockHash, bytes32 blockTarget);
    error InvalidBlockTime(uint32 blockTime, uint32 medianTime);

    event BlockHeaderAdded(uint256 indexed blockHeight, bytes32 indexed blockHash);

    struct BlockData {
        BlockHeaderData header;
        uint256 blockHeight;
    }
}
