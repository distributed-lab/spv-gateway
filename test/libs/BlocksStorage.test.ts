import { expect } from "chai";
import { ethers } from "hardhat";

import {
  getBlocksDataFilePath,
  Reverter,
  bitsToTarget,
  getBlockHeaderData,
  calculateWork,
  BlockStatus,
} from "@test-helpers";

import { BlockHeaderMock, BlocksStorageMock } from "@ethers-v6";

describe("BlocksStorage", () => {
  const reverter = new Reverter();

  const defaultPendingBlocksCount = 6;

  let blocksStorageLib: BlocksStorageMock;
  let blockHeaderLib: BlockHeaderMock;

  let genesisBlockDataFilePath: string;
  let firstBlocksDataFilePath: string;
  let newestBlocksDataFilePath: string;

  before(async () => {
    blocksStorageLib = await ethers.deployContract("BlocksStorageMock");
    blockHeaderLib = await ethers.deployContract("BlockHeaderMock");

    genesisBlockDataFilePath = getBlocksDataFilePath("genesis_block.json");
    firstBlocksDataFilePath = getBlocksDataFilePath("headers_1_10000.json");
    newestBlocksDataFilePath = getBlocksDataFilePath("headers_800352_815000.json");

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("#initialize", () => {
    it("should correctly initialize with genesis state", async () => {
      await blocksStorageLib["initialize(uint256)"](defaultPendingBlocksCount);

      const genesisBlockData = getBlockHeaderData(genesisBlockDataFilePath, 0);

      expect(await blocksStorageLib.getPendingBlockCount()).to.be.eq(defaultPendingBlocksCount);
      expect(await blocksStorageLib.getBlockHashByBlockHeight(0)).to.be.eq(genesisBlockData.blockHash);
      expect(await blocksStorageLib.getBlockHeight(genesisBlockData.blockHash)).to.be.eq(0);
      expect(await blocksStorageLib.getPrevBlockHash(genesisBlockData.blockHash)).to.be.eq(ethers.ZeroHash);
      expect(await blocksStorageLib.getBlockTimeByBlockHeight(0)).to.be.eq(genesisBlockData.parsedBlockHeader.time);
      expect(await blocksStorageLib.getBlockTime(genesisBlockData.blockHash)).to.be.eq(
        genesisBlockData.parsedBlockHeader.time,
      );
      expect(await blocksStorageLib.blockExists(genesisBlockData.blockHash)).to.be.true;
      expect(await blocksStorageLib.getBlockStatus(genesisBlockData.blockHash)).to.be.eq(BlockStatus.Pending);
      expect((await blocksStorageLib.getBlockData(genesisBlockData.blockHash)).cumulativeWork).to.be.eq(
        genesisBlockData.parsedBlockHeader.chainwork,
      );
    });

    it("should correctly initialize from some height", async () => {
      const startBlockHeight = 800352;
      const startBlockData = getBlockHeaderData(newestBlocksDataFilePath, startBlockHeight);

      const result = await blockHeaderLib.parseBlockHeaderData(startBlockData.rawHeader);
      const { prevBlockHash, merkleRoot, time, bits, nonce, version } = result[0];

      await blocksStorageLib[
        "initialize((bytes32,bytes32,uint32,uint32,uint32,bytes4),bytes32,uint256,uint256,uint256)"
      ](
        { prevBlockHash, merkleRoot, version, time, nonce, bits },
        startBlockData.blockHash,
        startBlockHeight,
        startBlockData.parsedBlockHeader.chainwork,
        defaultPendingBlocksCount,
      );

      expect(await blocksStorageLib.getPendingBlockCount()).to.be.eq(defaultPendingBlocksCount);
      expect(await blocksStorageLib.getBlockHashByBlockHeight(startBlockHeight)).to.be.eq(startBlockData.blockHash);
      expect(await blocksStorageLib.getBlockHeight(startBlockData.blockHash)).to.be.eq(startBlockHeight);
      expect(await blocksStorageLib.getPrevBlockHash(startBlockData.blockHash)).to.be.eq(
        startBlockData.parsedBlockHeader.previousblockhash,
      );
      expect(await blocksStorageLib.getBlockTimeByBlockHeight(startBlockHeight)).to.be.eq(
        startBlockData.parsedBlockHeader.time,
      );
      expect(await blocksStorageLib.getBlockTime(startBlockData.blockHash)).to.be.eq(
        startBlockData.parsedBlockHeader.time,
      );
      expect(await blocksStorageLib.blockExists(startBlockData.blockHash)).to.be.true;
      expect(await blocksStorageLib.getBlockStatus(startBlockData.blockHash)).to.be.eq(BlockStatus.Pending);
      expect((await blocksStorageLib.getBlockData(startBlockData.blockHash)).cumulativeWork).to.be.eq(
        startBlockData.parsedBlockHeader.chainwork,
      );
    });

    it("should get exception if try to call initialize function twice", async () => {
      await blocksStorageLib["initialize(uint256)"](defaultPendingBlocksCount);

      const startBlockHeight = 800352;
      const startBlockData = getBlockHeaderData(newestBlocksDataFilePath, startBlockHeight);

      const result = await blockHeaderLib.parseBlockHeaderData(startBlockData.rawHeader);
      const { prevBlockHash, merkleRoot, time, bits, nonce, version } = result[0];

      await expect(blocksStorageLib["initialize(uint256)"](defaultPendingBlocksCount)).to.be.revertedWithCustomError(
        blocksStorageLib,
        "BlocksStorageAlreadyInitialized",
      );

      await expect(
        blocksStorageLib["initialize((bytes32,bytes32,uint32,uint32,uint32,bytes4),bytes32,uint256,uint256,uint256)"](
          { prevBlockHash, merkleRoot, version, time, nonce, bits },
          startBlockData.blockHash,
          startBlockHeight,
          startBlockData.parsedBlockHeader.chainwork,
          defaultPendingBlocksCount,
        ),
      ).to.be.revertedWithCustomError(blocksStorageLib, "BlocksStorageAlreadyInitialized");
    });
  });

  describe("#addBlock", () => {
    it("should correctly add new blocks and update mainchain from genesis", async () => {
      await blocksStorageLib["initialize(uint256)"](defaultPendingBlocksCount);

      let blocksData = [];

      for (let i = 1; i <= 100; ++i) {
        const currentBlockData = getBlockHeaderData(firstBlocksDataFilePath, i);
        const { prevBlockHash, merkleRoot, time, bits, nonce, version } = (
          await blockHeaderLib.parseBlockHeaderData(currentBlockData.rawHeader)
        )[0];

        await blocksStorageLib.addBlock(
          { prevBlockHash, merkleRoot, time, bits, nonce, version },
          currentBlockData.blockHash,
          i,
          calculateWork(bitsToTarget(currentBlockData.parsedBlockHeader.bits)),
        );

        expect(await blocksStorageLib.blockExists(currentBlockData.blockHash)).to.be.true;
        expect(await blocksStorageLib.getBlockStatus(currentBlockData.blockHash)).to.be.eq(BlockStatus.Pending);
        expect(await blocksStorageLib.getMainchainHeight()).to.be.eq(i);
        expect((await blocksStorageLib.getBlockData(currentBlockData.blockHash)).cumulativeWork).to.be.eq(
          currentBlockData.parsedBlockHeader.chainwork,
        );

        blocksData.push(currentBlockData);

        if (i > defaultPendingBlocksCount) {
          expect(
            await blocksStorageLib.getBlockStatus(blocksData[i - defaultPendingBlocksCount - 1].blockHash),
          ).to.be.eq(BlockStatus.Active);
        }
      }
    });

    it("should correctly add new blocks and update mainchain from some block", async () => {
      const startBlockHeight = 800352;
      const startBlockData = getBlockHeaderData(newestBlocksDataFilePath, startBlockHeight);

      const { prevBlockHash, merkleRoot, time, bits, nonce, version } = (
        await blockHeaderLib.parseBlockHeaderData(startBlockData.rawHeader)
      )[0];

      await blocksStorageLib[
        "initialize((bytes32,bytes32,uint32,uint32,uint32,bytes4),bytes32,uint256,uint256,uint256)"
      ](
        { prevBlockHash, merkleRoot, version, time, nonce, bits },
        startBlockData.blockHash,
        startBlockHeight,
        startBlockData.parsedBlockHeader.chainwork,
        defaultPendingBlocksCount,
      );

      let blocksData = [];

      for (let i = 1; i <= 100; ++i) {
        const currentBlockHeight = startBlockHeight + i;
        const currentBlockData = getBlockHeaderData(newestBlocksDataFilePath, currentBlockHeight);
        const { prevBlockHash, merkleRoot, time, bits, nonce, version } = (
          await blockHeaderLib.parseBlockHeaderData(currentBlockData.rawHeader)
        )[0];

        await blocksStorageLib.addBlock(
          { prevBlockHash, merkleRoot, time, bits, nonce, version },
          currentBlockData.blockHash,
          currentBlockHeight,
          calculateWork(bitsToTarget(currentBlockData.parsedBlockHeader.bits)),
        );

        expect(await blocksStorageLib.blockExists(currentBlockData.blockHash)).to.be.true;
        expect(await blocksStorageLib.getBlockStatus(currentBlockData.blockHash)).to.be.eq(BlockStatus.Pending);
        expect(await blocksStorageLib.getMainchainHeight()).to.be.eq(currentBlockHeight);
        expect((await blocksStorageLib.getBlockData(currentBlockData.blockHash)).cumulativeWork).to.be.eq(
          currentBlockData.parsedBlockHeader.chainwork,
        );

        blocksData.push(currentBlockData);

        if (i > defaultPendingBlocksCount) {
          expect(
            await blocksStorageLib.getBlockStatus(blocksData[i - defaultPendingBlocksCount - 1].blockHash),
          ).to.be.eq(BlockStatus.Active);
        }
      }
    });

    it("should correctly add alternative blocks", async () => {});
  });
});
