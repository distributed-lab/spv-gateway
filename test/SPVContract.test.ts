import { expect } from "chai";
import { ethers } from "hardhat";

import { getBlockHeaderData, getBlocksDataFilePath, Reverter } from "@test-helpers";

import { BlockHeaderMock, SPVContractMock } from "@ethers-v6";

describe("SPVContract", () => {
  const reverter = new Reverter();

  const pendingBlockCount = 6;

  let spvContract: SPVContractMock;
  let blockHeaderLib: BlockHeaderMock;

  let firstBlocksDataFilePath: string;
  let newestBlocksDataFilePath: string;

  before(async () => {
    spvContract = await ethers.deployContract("SPVContractMock");
    blockHeaderLib = await ethers.deployContract("BlockHeaderMock");

    await spvContract.__SPVContract_init(pendingBlockCount, pendingBlockCount);

    firstBlocksDataFilePath = getBlocksDataFilePath("headers_1_10000.json");
    newestBlocksDataFilePath = getBlocksDataFilePath("headers_800352_815000.json");

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe("#addBlockHeader", () => {
    it("should correctly add several block headers from genesis state", async () => {
      for (let i = 1; i <= 100; ++i) {
        const currentBlockData = getBlockHeaderData(firstBlocksDataFilePath, i);

        const tx = await spvContract.addBlockHeader(currentBlockData.rawHeader);

        await expect(tx).to.emit(spvContract, "BlockHeaderAdded").withArgs(i, currentBlockData.blockHash);

        expect(await spvContract.isInMainchain(currentBlockData.blockHash)).to.be.true;
        expect(await spvContract.getNextMainchainBlock(currentBlockData.parsedBlockHeader.previousblockhash)).to.be.eq(
          currentBlockData.blockHash,
        );
      }
    });
  });
});
