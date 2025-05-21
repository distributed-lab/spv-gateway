import { expect } from "chai";
import { ethers } from "hardhat";

import {
  getBlocksDataFilePath,
  Reverter,
  bitsToTarget,
  getBlockHeaderData,
  DIFFICULTY_ADJSTMENT_INTERVAL,
  INITIAL_TARGET,
} from "@test-helpers";

import { TargetsStorageMock } from "@ethers-v6";

describe("TargetsStorage", () => {
  const reverter = new Reverter();

  let targetsStorageLib: TargetsStorageMock;

  let firstBlocksDataFilePath: string;
  let newestBlocksDataFilePath: string;

  before(async () => {
    targetsStorageLib = await ethers.deployContract("TargetsStorageMock");

    firstBlocksDataFilePath = getBlocksDataFilePath("headers_1_10000.json");
    newestBlocksDataFilePath = getBlocksDataFilePath("headers_800352_815000.json");

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("#initialize", () => {
    it("should correctly initialize with genesis state", async () => {
      await targetsStorageLib["initialize()"]();

      expect(await targetsStorageLib.getLastTarget()).to.be.eq(INITIAL_TARGET);
      expect(await targetsStorageLib.getLastEpoch()).to.be.eq(1);
      expect(await targetsStorageLib.getTargetByBlockHeight(10)).to.be.eq(INITIAL_TARGET);
      expect(await targetsStorageLib.getTarget(1)).to.be.eq(INITIAL_TARGET);
      expect(await targetsStorageLib.hasPendingTarget()).to.be.false;
    });

    it("should correctly initialize from some height", async () => {
      const startBlockHeight = 800352;
      const blockData = getBlockHeaderData(newestBlocksDataFilePath, startBlockHeight);
      const blockTarget = bitsToTarget(blockData.parsedBlockHeader.bits);

      expect(await targetsStorageLib.isTargetAdjustmentBlock(startBlockHeight)).to.be.true;

      await targetsStorageLib["initialize(uint256,bytes32)"](startBlockHeight, blockTarget);

      const expectedEpoch = startBlockHeight / DIFFICULTY_ADJSTMENT_INTERVAL + 1;

      expect(await targetsStorageLib.getLastTarget()).to.be.eq(blockTarget);
      expect(await targetsStorageLib.getLastEpoch()).to.be.eq(expectedEpoch);
      expect(await targetsStorageLib.getTargetByBlockHeight(startBlockHeight + 10)).to.be.eq(blockTarget);
      expect(await targetsStorageLib.getTarget(expectedEpoch)).to.be.eq(blockTarget);
      expect(await targetsStorageLib.hasPendingTarget()).to.be.false;
    });

    it("should get exception if try to call initialize function twice", async () => {
      await targetsStorageLib["initialize()"]();

      await expect(targetsStorageLib["initialize()"]()).to.be.revertedWithCustomError(
        targetsStorageLib,
        "TargetsStorageAlreadyInitialized",
      );
      await expect(
        targetsStorageLib["initialize(uint256,bytes32)"](DIFFICULTY_ADJSTMENT_INTERVAL, INITIAL_TARGET),
      ).to.be.revertedWithCustomError(targetsStorageLib, "TargetsStorageAlreadyInitialized");
    });
  });

  describe("#updatePendingTarget", () => {
    it("should correctly update pending target", async () => {
      const firstEpochBlockHeight = 800352;
      const firstEpochBlockData = getBlockHeaderData(newestBlocksDataFilePath, firstEpochBlockHeight);
      const lastEpochBlockData = getBlockHeaderData(
        newestBlocksDataFilePath,
        firstEpochBlockHeight + DIFFICULTY_ADJSTMENT_INTERVAL - 1,
      );

      const blockHeight = firstEpochBlockHeight + DIFFICULTY_ADJSTMENT_INTERVAL;
      const targetAdjustmentBlock = getBlockHeaderData(newestBlocksDataFilePath, blockHeight);

      await targetsStorageLib["initialize(uint256,bytes32)"](
        firstEpochBlockHeight,
        bitsToTarget(lastEpochBlockData.parsedBlockHeader.bits),
      );

      await targetsStorageLib.updatePendingTarget(
        blockHeight,
        targetAdjustmentBlock.blockHash,
        firstEpochBlockData.parsedBlockHeader.time,
        lastEpochBlockData.parsedBlockHeader.time,
      );

      const expectedPendingEpoch = blockHeight / DIFFICULTY_ADJSTMENT_INTERVAL + 1;

      expect(await targetsStorageLib.hasPendingTarget()).to.be.true;
      expect(await targetsStorageLib.getPendingTarget(targetAdjustmentBlock.blockHash)).to.be.eq(
        bitsToTarget(targetAdjustmentBlock.parsedBlockHeader.bits),
      );
      expect(await targetsStorageLib.getPendingEpoch()).to.be.eq(expectedPendingEpoch);
    });

    it("should get exception if passed block is not an target adjustment block", async () => {
      await targetsStorageLib["initialize()"]();

      const wrongHeight = 123;
      const blockData = getBlockHeaderData(firstBlocksDataFilePath, wrongHeight);

      await expect(
        targetsStorageLib.updatePendingTarget(
          wrongHeight,
          blockData.blockHash,
          blockData.parsedBlockHeader.time,
          BigInt(blockData.parsedBlockHeader.time) + 1n,
        ),
      )
        .to.be.revertedWithCustomError(targetsStorageLib, "NotATargetAdjustmentBlock")
        .withArgs(wrongHeight);
    });

    it("should get exception if pass invalid epoch time values", async () => {
      await targetsStorageLib["initialize()"]();

      const blockData = getBlockHeaderData(firstBlocksDataFilePath, DIFFICULTY_ADJSTMENT_INTERVAL);

      await expect(
        targetsStorageLib.updatePendingTarget(
          DIFFICULTY_ADJSTMENT_INTERVAL,
          blockData.blockHash,
          blockData.parsedBlockHeader.time,
          blockData.parsedBlockHeader.time,
        ),
      )
        .to.be.revertedWithCustomError(targetsStorageLib, "InvalidEpochTimeParameters")
        .withArgs(blockData.parsedBlockHeader.time, blockData.parsedBlockHeader.time);
    });
  });

  describe("#confirmPendingTarget", () => {
    const startBlockHeight = 800352;

    beforeEach("setup", async () => {
      const startBlockData = getBlockHeaderData(newestBlocksDataFilePath, startBlockHeight);

      await targetsStorageLib["initialize(uint256,bytes32)"](
        startBlockHeight,
        bitsToTarget(startBlockData.parsedBlockHeader.bits),
      );
    });

    it("should correctly confirm pending target", async () => {
      const startBlockData = getBlockHeaderData(newestBlocksDataFilePath, startBlockHeight);
      const lastEpochBlockData = getBlockHeaderData(
        newestBlocksDataFilePath,
        startBlockHeight + DIFFICULTY_ADJSTMENT_INTERVAL - 1,
      );

      const blockHeight = startBlockHeight + DIFFICULTY_ADJSTMENT_INTERVAL;
      const targetAdjustmentBlock = getBlockHeaderData(newestBlocksDataFilePath, blockHeight);

      await targetsStorageLib.updatePendingTarget(
        blockHeight,
        targetAdjustmentBlock.blockHash,
        startBlockData.parsedBlockHeader.time,
        lastEpochBlockData.parsedBlockHeader.time,
      );

      const expectedPendingEpoch = blockHeight / DIFFICULTY_ADJSTMENT_INTERVAL + 1;

      expect(await targetsStorageLib.hasPendingTarget()).to.be.true;
      expect(await targetsStorageLib.getLastEpoch()).to.be.eq(expectedPendingEpoch - 1);

      await targetsStorageLib.confirmPendingTarget(targetAdjustmentBlock.blockHash);

      expect(await targetsStorageLib.hasPendingTarget()).to.be.false;
      expect(await targetsStorageLib.getPendingEpoch()).to.be.eq(0);
      expect(await targetsStorageLib.getPendingTarget(targetAdjustmentBlock.blockHash)).to.be.eq(ethers.ZeroHash);

      expect(await targetsStorageLib.getLastEpoch()).to.be.eq(expectedPendingEpoch);
      expect(await targetsStorageLib.getLastTarget()).to.be.eq(
        bitsToTarget(targetAdjustmentBlock.parsedBlockHeader.bits),
      );
    });

    it("should get exception if try to confirm invalid block hash", async () => {
      const startBlockData = getBlockHeaderData(newestBlocksDataFilePath, startBlockHeight);
      const lastEpochBlockData = getBlockHeaderData(
        newestBlocksDataFilePath,
        startBlockHeight + DIFFICULTY_ADJSTMENT_INTERVAL - 1,
      );

      await expect(targetsStorageLib.confirmPendingTarget(lastEpochBlockData.blockHash))
        .to.be.revertedWithCustomError(targetsStorageLib, "InvalidConfirmedBlockHash")
        .withArgs(lastEpochBlockData.blockHash);

      const blockHeight = startBlockHeight + DIFFICULTY_ADJSTMENT_INTERVAL;
      const targetAdjustmentBlock = getBlockHeaderData(newestBlocksDataFilePath, blockHeight);

      await targetsStorageLib.updatePendingTarget(
        blockHeight,
        targetAdjustmentBlock.blockHash,
        startBlockData.parsedBlockHeader.time,
        lastEpochBlockData.parsedBlockHeader.time,
      );

      await expect(targetsStorageLib.confirmPendingTarget(lastEpochBlockData.blockHash))
        .to.be.revertedWithCustomError(targetsStorageLib, "InvalidConfirmedBlockHash")
        .withArgs(lastEpochBlockData.blockHash);
    });
  });
});
