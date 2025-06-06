import { expect } from "chai";
import { ethers } from "hardhat";

import {
  bitsToTarget,
  checkBlockHeaderData,
  DIFFICULTY_ADJUSTMENT_INTERVAL,
  getBlockHeaderData,
  getBlockHeaderDataBatch,
  getBlocksDataFilePath,
  Reverter,
} from "@test-helpers";

import { BlockHeaderMock, SPVContractMock } from "@ethers-v6";

describe("SPVContract", () => {
  const reverter = new Reverter();

  let spvContract: SPVContractMock;
  let blockHeaderLib: BlockHeaderMock;

  let genesisBlockDataFilePath: string;
  let firstBlocksDataFilePath: string;
  let newestBlocksDataFilePath: string;

  before(async () => {
    spvContract = await ethers.deployContract("SPVContractMock");
    blockHeaderLib = await ethers.deployContract("BlockHeaderMock");

    genesisBlockDataFilePath = getBlocksDataFilePath("genesis_block.json");
    firstBlocksDataFilePath = getBlocksDataFilePath("headers_1_10000.json");
    newestBlocksDataFilePath = getBlocksDataFilePath("headers_800352_815000.json");

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("#initialize", () => {
    it("should correctly init SPV contract from genesis state", async () => {
      const genesisData = getBlockHeaderData(genesisBlockDataFilePath, 0);

      const tx = await spvContract["__SPVContract_init()"]();

      await expect(tx).to.emit(spvContract, "MainchainHeadUpdated").withArgs(genesisData.height, genesisData.blockHash);
      await expect(tx).to.emit(spvContract, "BlockHeaderAdded").withArgs(genesisData.height, genesisData.blockHash);
    });

    it("should correctly init SPV contract from some block", async () => {
      const initBlockHeight = 802_368;

      const lastEpochCumulativeWork = getBlockHeaderData(newestBlocksDataFilePath, initBlockHeight - 1)
        .parsedBlockHeader.chainwork;
      const initBlockData = getBlockHeaderData(newestBlocksDataFilePath, initBlockHeight);

      const tx = await spvContract["__SPVContract_init(bytes,uint256,uint256)"](
        initBlockData.rawHeader,
        initBlockData.height,
        lastEpochCumulativeWork,
      );

      await expect(tx)
        .to.emit(spvContract, "MainchainHeadUpdated")
        .withArgs(initBlockData.height, initBlockData.blockHash);
      await expect(tx).to.emit(spvContract, "BlockHeaderAdded").withArgs(initBlockData.height, initBlockData.blockHash);

      expect(await spvContract.getLastEpochCumulativeWork()).to.be.eq(lastEpochCumulativeWork);
      expect(await spvContract.getMainchainHead()).to.be.eq(initBlockData.blockHash);
      expect(await spvContract.getMainchainBlockHeight()).to.be.eq(initBlockData.height);
    });

    it("should get exception if pass invalid block height", async () => {
      const initBlockHeight = 802_367;

      const lastEpochCumulativeWork = getBlockHeaderData(newestBlocksDataFilePath, initBlockHeight - 1)
        .parsedBlockHeader.chainwork;
      const initBlockData = getBlockHeaderData(newestBlocksDataFilePath, initBlockHeight);

      await expect(
        spvContract["__SPVContract_init(bytes,uint256,uint256)"](
          initBlockData.rawHeader,
          initBlockData.height,
          lastEpochCumulativeWork,
        ),
      )
        .to.be.revertedWithCustomError(spvContract, "InvalidInitialBlockHeight")
        .withArgs(initBlockHeight);
    });

    it("should get exception if try to call init function twice", async () => {
      await spvContract["__SPVContract_init()"]();

      await expect(spvContract["__SPVContract_init()"]()).to.be.revertedWithCustomError(
        spvContract,
        "InvalidInitialization",
      );

      const initBlockHeight = 802_368;
      const lastEpochCumulativeWork = getBlockHeaderData(newestBlocksDataFilePath, initBlockHeight - 1)
        .parsedBlockHeader.chainwork;
      const initBlockData = getBlockHeaderData(newestBlocksDataFilePath, initBlockHeight);

      await expect(
        spvContract["__SPVContract_init(bytes,uint256,uint256)"](
          initBlockData.rawHeader,
          initBlockData.height,
          lastEpochCumulativeWork,
        ),
      ).to.be.revertedWithCustomError(spvContract, "InvalidInitialization");
    });
  });

  describe("#addBlockHeaderBatch", () => {
    it("should correctly add block headers and update all related data", async () => {
      const initBlockHeight = 802_368;

      const lastEpochCumulativeWork = getBlockHeaderData(newestBlocksDataFilePath, initBlockHeight - 1)
        .parsedBlockHeader.chainwork;
      const initBlockData = getBlockHeaderData(newestBlocksDataFilePath, initBlockHeight);

      await spvContract["__SPVContract_init(bytes,uint256,uint256)"](
        initBlockData.rawHeader,
        initBlockData.height,
        lastEpochCumulativeWork,
      );

      const batchSize = 200;
      const batchesCount = 11;
      const totalBlockToAdd = batchSize * batchesCount;
      const blocksData = getBlockHeaderDataBatch(newestBlocksDataFilePath, initBlockHeight + 1, totalBlockToAdd);

      let currentMainchainHead = initBlockData.blockHash;

      expect(await spvContract.getMainchainHead()).to.be.eq(currentMainchainHead);

      for (let i = 0; i < batchesCount; i++) {
        const currentBlocksData = blocksData.slice(batchSize * i, batchSize * (i + 1));
        const rawHeaders = currentBlocksData.map((headerData) => headerData.rawHeader);

        const tx = await spvContract.addBlockHeaderBatch(rawHeaders);

        await expect(tx)
          .to.emit(spvContract, "MainchainHeadUpdated")
          .withArgs(currentBlocksData[batchSize - 1].height, currentBlocksData[batchSize - 1].blockHash);
      }

      expect(await spvContract.getLastEpochCumulativeWork()).to.be.eq(
        blocksData[DIFFICULTY_ADJUSTMENT_INTERVAL - 2].parsedBlockHeader.chainwork,
      );
      expect(await spvContract.getMainchainHead()).to.be.eq(blocksData[totalBlockToAdd - 1].blockHash);
      expect(await spvContract.getMainchainBlockHeight()).to.be.eq(initBlockHeight + totalBlockToAdd);

      await Promise.all(
        blocksData.map((data) => {
          return new Promise(async (resolve) => {
            expect(await spvContract.isInMainchain(data.blockHash)).to.be.true;

            resolve(true);
          });
        }),
      );
    });

    it("should get exception if the first block does not exist", async () => {
      await spvContract["__SPVContract_init()"]();

      const blockHeadersData = [];

      for (let i = 2; i <= 10; ++i) {
        blockHeadersData.push(getBlockHeaderData(firstBlocksDataFilePath, i));
      }

      const rawHeaders = blockHeadersData.map((headerData) => headerData.rawHeader);

      await expect(spvContract.addBlockHeaderBatch(rawHeaders))
        .to.revertedWithCustomError(spvContract, "PrevBlockDoesNotExist")
        .withArgs(blockHeadersData[0].parsedBlockHeader.previousblockhash);
    });

    it("should get exception if pass block headers in the invalid order", async () => {
      await spvContract["__SPVContract_init()"]();

      await expect(
        spvContract.addBlockHeaderBatch([
          getBlockHeaderData(firstBlocksDataFilePath, 1).rawHeader,
          getBlockHeaderData(firstBlocksDataFilePath, 3).rawHeader,
        ]),
      ).to.revertedWithCustomError(spvContract, "InvalidBlockHeadersOrder");
    });

    it("should get exception if pass zero array", async () => {
      await spvContract["__SPVContract_init()"]();

      await expect(spvContract.addBlockHeaderBatch([])).to.revertedWithCustomError(
        spvContract,
        "EmptyBlockHeaderArray",
      );
    });
  });

  describe("#addBlockHeader", () => {
    it("should correctly add new block header", async () => {
      await spvContract["__SPVContract_init()"]();

      const firstBlockData = getBlockHeaderData(firstBlocksDataFilePath, 1);
      const secondBlockData = getBlockHeaderData(firstBlocksDataFilePath, 2);

      expect((await spvContract.getBlockInfo(firstBlockData.blockHash)).isInMainchain).to.be.false;

      let tx = await spvContract.addBlockHeader(firstBlockData.rawHeader);

      let expectedMainchainHead = firstBlockData.blockHash;
      let expectedMainchainBlockHeight = 1;

      await expect(tx)
        .to.emit(spvContract, "BlockHeaderAdded")
        .withArgs(expectedMainchainBlockHeight, expectedMainchainHead);
      await expect(tx)
        .to.emit(spvContract, "MainchainHeadUpdated")
        .withArgs(expectedMainchainBlockHeight, expectedMainchainHead);

      expect(await spvContract.getMainchainHead()).to.be.eq(expectedMainchainHead);
      expect(await spvContract.getMainchainBlockHeight()).to.be.eq(expectedMainchainBlockHeight);
      expect(await spvContract.getBlockHeight(expectedMainchainHead)).to.be.eq(expectedMainchainBlockHeight);
      expect(await spvContract.getBlockMerkleRoot(expectedMainchainHead)).to.be.eq(
        firstBlockData.parsedBlockHeader.merkleroot,
      );

      let blockInfo = await spvContract.getBlockInfo(expectedMainchainHead);

      checkBlockHeaderData(blockInfo.mainBlockData.header, firstBlockData);
      expect(blockInfo.mainBlockData.blockHeight).to.be.eq(expectedMainchainBlockHeight);
      expect(blockInfo.isInMainchain).to.be.true;
      expect(blockInfo.cumulativeWork).to.be.eq(firstBlockData.parsedBlockHeader.chainwork);

      tx = await spvContract.addBlockHeader(secondBlockData.rawHeader);

      expectedMainchainHead = secondBlockData.blockHash;
      expectedMainchainBlockHeight = 2;

      await expect(tx)
        .to.emit(spvContract, "BlockHeaderAdded")
        .withArgs(expectedMainchainBlockHeight, expectedMainchainHead);
      await expect(tx)
        .to.emit(spvContract, "MainchainHeadUpdated")
        .withArgs(expectedMainchainBlockHeight, expectedMainchainHead);

      blockInfo = await spvContract.getBlockInfo(expectedMainchainHead);

      checkBlockHeaderData(blockInfo.mainBlockData.header, secondBlockData);
      expect(blockInfo.mainBlockData.blockHeight).to.be.eq(expectedMainchainBlockHeight);
      expect(blockInfo.isInMainchain).to.be.true;
      expect(blockInfo.cumulativeWork).to.be.eq(secondBlockData.parsedBlockHeader.chainwork);
    });

    it("should correctly add target adjustment block", async () => {
      const initBlockHeight = 802_368;

      const lastEpochCumulativeWork = getBlockHeaderData(newestBlocksDataFilePath, initBlockHeight - 1)
        .parsedBlockHeader.chainwork;
      const initBlockData = getBlockHeaderData(newestBlocksDataFilePath, initBlockHeight);

      await spvContract["__SPVContract_init(bytes,uint256,uint256)"](
        initBlockData.rawHeader,
        initBlockData.height,
        lastEpochCumulativeWork,
      );

      const batchSize = 200;
      const batchesCount = 10;
      const totalBlockToAdd = batchSize * batchesCount;
      let blocksData = getBlockHeaderDataBatch(newestBlocksDataFilePath, initBlockHeight + 1, totalBlockToAdd);

      for (let i = 0; i < batchesCount; i++) {
        const currentBlocksData = blocksData.slice(batchSize * i, batchSize * (i + 1));
        const rawHeaders = currentBlocksData.map((headerData) => headerData.rawHeader);

        await spvContract.addBlockHeaderBatch(rawHeaders);
      }

      const blocksToAdd = 20;
      const newBlockHeight = initBlockHeight + totalBlockToAdd + 1;
      blocksData = getBlockHeaderDataBatch(newestBlocksDataFilePath, newBlockHeight, blocksToAdd);

      for (let i = 0; i < blocksToAdd; i++) {
        if ((newBlockHeight + i) % DIFFICULTY_ADJUSTMENT_INTERVAL != 0) {
          await spvContract.addBlockHeader(blocksData[i].rawHeader);
        } else {
          await spvContract.addBlockHeader(blocksData[i].rawHeader);

          expect((await spvContract.getBlockInfo(blocksData[i].blockHash)).cumulativeWork).to.be.eq(
            blocksData[i].parsedBlockHeader.chainwork,
          );
          expect(await spvContract.getLastEpochCumulativeWork()).to.be.eq(
            blocksData[i - 1].parsedBlockHeader.chainwork,
          );
        }
      }
    });

    it("should get exception if pass block that already exists", async () => {
      await spvContract["__SPVContract_init()"]();

      const currentBlockData = getBlockHeaderData(firstBlocksDataFilePath, 1);

      await spvContract.addBlockHeader(currentBlockData.rawHeader);

      await expect(spvContract.addBlockHeader(currentBlockData.rawHeader))
        .to.be.revertedWithCustomError(spvContract, "BlockAlreadyExists")
        .withArgs(currentBlockData.blockHash);
    });

    it("should get exception if prev block hash is not in the chain", async () => {
      await spvContract["__SPVContract_init()"]();

      const firstBlockData = getBlockHeaderData(firstBlocksDataFilePath, 1);
      const thirdBlockData = getBlockHeaderData(firstBlocksDataFilePath, 3);

      await spvContract.addBlockHeader(firstBlockData.rawHeader);

      await expect(spvContract.addBlockHeader(thirdBlockData.rawHeader))
        .to.be.revertedWithCustomError(spvContract, "PrevBlockDoesNotExist")
        .withArgs(thirdBlockData.parsedBlockHeader.previousblockhash);
    });
  });

  describe("#getStorageMedianTime", () => {
    beforeEach("setup", async () => {
      await spvContract["__SPVContract_init()"]();
    });

    it("should return correct median time for the first block", async () => {
      const currentBlockData = getBlockHeaderData(firstBlocksDataFilePath, 1);

      expect(await spvContract.getStorageMedianTime(currentBlockData.rawHeader, 1)).to.be.eq(
        currentBlockData.parsedBlockHeader.time,
      );
    });

    it("should return correct median time for the first 11 blocks", async () => {
      const blocksData = [];

      for (let i = 1; i <= 11; ++i) {
        const currentBlockData = getBlockHeaderData(firstBlocksDataFilePath, i);

        await spvContract.addBlockHeader(currentBlockData.rawHeader);

        expect(await spvContract.getBlockHeight(currentBlockData.blockHash)).to.be.eq(i);

        blocksData.push(currentBlockData);

        if (i > 1) {
          expect(await spvContract.getStorageMedianTime(currentBlockData.rawHeader, 1)).to.be.eq(
            blocksData[i - 1].parsedBlockHeader.time,
          );
        }
      }
    });

    it("should return correct median time for block height > 11", async () => {
      const blockHeadersData = [];

      for (let i = 1; i <= 100; ++i) {
        blockHeadersData.push(getBlockHeaderData(firstBlocksDataFilePath, i));
      }

      await spvContract.addBlockHeaderBatch(blockHeadersData.map((headerData) => headerData.rawHeader));

      for (let i = 12; i < 100; ++i) {
        expect(await spvContract.getStorageMedianTime(blockHeadersData[i - 1].rawHeader, i)).to.be.eq(
          blockHeadersData[i - 2].parsedBlockHeader.mediantime,
        );
      }
    });
  });

  describe("#getMemoryMedianTime", async () => {
    beforeEach("setup", async () => {
      await spvContract["__SPVContract_init()"]();
    });

    it("should return correct median time", async () => {
      const blockHeadersData = getBlockHeaderDataBatch(firstBlocksDataFilePath, 1, 100);

      const rawHeaders = blockHeadersData.map((headerData) => headerData.rawHeader);
      await spvContract.addBlockHeaderBatch(rawHeaders);

      for (let i = 12; i < 100; ++i) {
        expect(await spvContract.getMemoryMedianTime(rawHeaders, i)).to.be.eq(
          blockHeadersData[i - 1].parsedBlockHeader.mediantime,
        );
      }
    });

    it("should return 0 if pass array with length < 11", async () => {
      const blockHeadersData = getBlockHeaderDataBatch(firstBlocksDataFilePath, 1, 10);
      const rawHeaders = blockHeadersData.map((headerData) => headerData.rawHeader);

      for (let i = 1; i <= 10; ++i) {
        expect(await spvContract.getMemoryMedianTime(rawHeaders, i)).to.be.eq(0);
      }
    });
  });

  describe("#validateBlockRules", () => {
    const initBlockHeight = 802_368;

    beforeEach("#setup", async () => {
      const lastEpochCumulativeWork = getBlockHeaderData(newestBlocksDataFilePath, initBlockHeight - 1)
        .parsedBlockHeader.chainwork;
      const initBlockData = getBlockHeaderData(newestBlocksDataFilePath, initBlockHeight);

      await spvContract["__SPVContract_init(bytes,uint256,uint256)"](
        initBlockData.rawHeader,
        initBlockData.height,
        lastEpochCumulativeWork,
      );
    });

    it("should get exception if pass invalid bits field", async () => {
      const newBlockData = getBlockHeaderData(newestBlocksDataFilePath, initBlockHeight + 1);

      const mockBits = ethers.toBeHex(BigInt(newBlockData.parsedBlockHeader.bits) + 1000n);

      const mockTarget = bitsToTarget(mockBits);
      const target = bitsToTarget(newBlockData.parsedBlockHeader.bits);

      await expect(
        spvContract.validateBlockRules(
          {
            prevBlockHash: newBlockData.parsedBlockHeader.previousblockhash,
            merkleRoot: newBlockData.parsedBlockHeader.merkleroot,
            version: newBlockData.parsedBlockHeader.version,
            time: newBlockData.parsedBlockHeader.time,
            nonce: newBlockData.parsedBlockHeader.nonce,
            bits: mockBits,
          },
          newBlockData.blockHash,
          target,
          newBlockData.parsedBlockHeader.mediantime,
        ),
      )
        .to.be.revertedWithCustomError(spvContract, "InvalidTarget")
        .withArgs(mockTarget, target);
    });

    it("should get exception if block hash higher than target", async () => {
      const newBlockData = getBlockHeaderData(newestBlocksDataFilePath, initBlockHeight + 1);

      const mockBits = ethers.toBeHex(BigInt(newBlockData.parsedBlockHeader.bits) - 500000n);
      const mockTarget = bitsToTarget(mockBits);

      await expect(
        spvContract.validateBlockRules(
          {
            prevBlockHash: newBlockData.parsedBlockHeader.previousblockhash,
            merkleRoot: newBlockData.parsedBlockHeader.merkleroot,
            version: newBlockData.parsedBlockHeader.version,
            time: newBlockData.parsedBlockHeader.time,
            nonce: newBlockData.parsedBlockHeader.nonce,
            bits: mockBits,
          },
          newBlockData.blockHash,
          mockTarget,
          newBlockData.parsedBlockHeader.mediantime,
        ),
      )
        .to.be.revertedWithCustomError(spvContract, "InvalidBlockHash")
        .withArgs(newBlockData.blockHash, mockTarget);
    });

    it("should get exception if block time less than the median time", async () => {
      const newBlockData = getBlockHeaderData(newestBlocksDataFilePath, initBlockHeight + 1);

      const target = bitsToTarget(newBlockData.parsedBlockHeader.bits);
      const mockTime = BigInt(newBlockData.parsedBlockHeader.mediantime) - 100n;

      await expect(
        spvContract.validateBlockRules(
          {
            prevBlockHash: newBlockData.parsedBlockHeader.previousblockhash,
            merkleRoot: newBlockData.parsedBlockHeader.merkleroot,
            version: newBlockData.parsedBlockHeader.version,
            time: mockTime,
            nonce: newBlockData.parsedBlockHeader.nonce,
            bits: newBlockData.parsedBlockHeader.bits,
          },
          newBlockData.blockHash,
          target,
          newBlockData.parsedBlockHeader.mediantime,
        ),
      )
        .to.be.revertedWithCustomError(spvContract, "InvalidBlockTime")
        .withArgs(mockTime, newBlockData.parsedBlockHeader.mediantime);
    });
  });
});
