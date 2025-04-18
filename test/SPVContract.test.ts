import { expect } from "chai";
import { ethers } from "hardhat";

import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

import { Reverter } from "@test-helpers";

import { SPVContract } from "@ethers-v6";

describe("SPVContract", () => {
  const reverter = new Reverter();

  const pendingBlockCount = 6;

  let OWNER: SignerWithAddress;
  let SECOND: SignerWithAddress;

  let spvContract: SPVContract;

  before(async () => {
    [OWNER, SECOND] = await ethers.getSigners();

    spvContract = await ethers.deployContract("SPVContract");

    await spvContract.__SPVContract_init(pendingBlockCount, pendingBlockCount);

    await reverter.snapshot();
  });

  afterEach(reverter.revert);

  describe.only("#test", () => {
    it("test", async () => {
      await spvContract.addBlockHeader(
        "0x010000006fe28c0ab6f1b372c1a6a246ae63f74f931e8365e15a089c68d6190000000000982051fd1e4ba744bbbe680e1fee14677ba1a3c3540bf7b1cdb606e857233e0e61bc6649ffff001d01e36299",
      );
      await spvContract.addBlockHeader(
        "0x010000004860eb18bf1b1620e37e9490fc8a427514416fd75159ab86688e9a8300000000d5fdcc541e25de1c7a5addedf24858b8bb665c9f36ef744ee42c316022c90f9bb0bc6649ffff001d08d2bd61",
      );
      await spvContract.addBlockHeader(
        "0x01000000bddd99ccfda39da1b108ce1a5d70038d0a967bacb68b6b63065f626a0000000044f672226090d85db9a9f2fbfe5f0f9609b387af7be5b7fbb7a1767c831c9e995dbe6649ffff001d05e0ed6d",
      );
      await spvContract.addBlockHeader(
        "0x010000004944469562ae1c2c74d9a535e00b6f3e40ffbad4f2fda3895501b582000000007a06ea98cd40ba2e3288262b28638cec5337c1456aaf5eedc8e9e5a20f062bdf8cc16649ffff001d2bfee0a9",
      );
    });
  });
});
