import * as fs from "fs";
import path from "path";
import { expect } from "chai";
import { randomInt } from "crypto";

import { ISPVGateway } from "@/generated-types/ethers/contracts/SPVGateway";

import { BlockHeaderData, ReorgBlocksData } from "./types";

export function getRandomBlockHeaderData(pathToDataFile: string, minHeight: number, maxHeight: number) {
  const randHeight = randomInt(minHeight, maxHeight + 1);

  return getBlockHeaderData(pathToDataFile, randHeight);
}

export function getBlocksDataFilePath(fileName: string): string {
  return path.join(__dirname, "../data", fileName);
}

export function getReorgBlockHeaderData(
  pathToDataFile: string,
  height: number,
  isMainchain: boolean = true,
): BlockHeaderData {
  const blocksData = JSON.parse(fs.readFileSync(pathToDataFile, "utf-8")) as ReorgBlocksData;
  const firstElementHeight = isMainchain
    ? blocksData.mainchainHeaders[0].height
    : blocksData.forkChainHeaders[0].height;

  return isMainchain
    ? formatBlockHeaderData(blocksData.mainchainHeaders[height - Number(firstElementHeight)])
    : formatBlockHeaderData(blocksData.forkChainHeaders[height - Number(firstElementHeight)]);
}

export function getReorgBlockHeaderDataBatch(
  pathToDataFile: string,
  height: number,
  batchSize: number,
  isMainchain: boolean = true,
): BlockHeaderData[] {
  const allBlocksDataArr = JSON.parse(fs.readFileSync(pathToDataFile, "utf-8")) as ReorgBlocksData;
  const firstElementHeight = isMainchain
    ? allBlocksDataArr.mainchainHeaders[0].height
    : allBlocksDataArr.forkChainHeaders[0].height;

  const blocksData = [];

  for (let i = 0; i < batchSize; i++) {
    blocksData.push(
      isMainchain
        ? formatBlockHeaderData(allBlocksDataArr.mainchainHeaders[height + i - Number(firstElementHeight)])
        : formatBlockHeaderData(allBlocksDataArr.forkChainHeaders[height + i - Number(firstElementHeight)]),
    );
  }

  return blocksData;
}

export function getBlockHeaderData(pathToDataFile: string, height: number): BlockHeaderData {
  const allBlocksDataArr = JSON.parse(fs.readFileSync(pathToDataFile, "utf-8")) as BlockHeaderData[];
  const firstElementHeight = allBlocksDataArr[0].height;

  return formatBlockHeaderData(allBlocksDataArr[height - Number(firstElementHeight)]);
}

export function getBlockHeaderDataBatch(pathToDataFile: string, height: number, batchSize: number): BlockHeaderData[] {
  const allBlocksDataArr = JSON.parse(fs.readFileSync(pathToDataFile, "utf-8")) as BlockHeaderData[];
  const firstElementHeight = allBlocksDataArr[0].height;

  const blocksData = [];

  for (let i = 0; i < batchSize; i++) {
    blocksData.push(formatBlockHeaderData(allBlocksDataArr[height + i - Number(firstElementHeight)]));
  }

  return blocksData;
}

export function checkBlockHeaderData(
  actualBlockHeaderData: ISPVGateway.BlockDataStructOutput,
  expectedBlockHeaderData: BlockHeaderData,
) {
  expect(actualBlockHeaderData.version).to.be.eq(expectedBlockHeaderData.parsedBlockHeader.version);
  expect(actualBlockHeaderData.bits).to.be.eq(expectedBlockHeaderData.parsedBlockHeader.bits);
  expect(actualBlockHeaderData.prevBlockHash).to.be.eq(expectedBlockHeaderData.parsedBlockHeader.previousblockhash);
  expect(actualBlockHeaderData.merkleRoot).to.be.eq(expectedBlockHeaderData.parsedBlockHeader.merkleroot);
  expect(actualBlockHeaderData.nonce).to.be.eq(expectedBlockHeaderData.parsedBlockHeader.nonce);
  expect(actualBlockHeaderData.time).to.be.eq(expectedBlockHeaderData.parsedBlockHeader.time);
}

export function formatBlockHeaderData(headerData: BlockHeaderData): BlockHeaderData {
  headerData.blockHash = addHexPrefix(headerData.blockHash);
  headerData.rawHeader = addHexPrefix(headerData.rawHeader);
  headerData.parsedBlockHeader.hash = addHexPrefix(headerData.parsedBlockHeader.hash);
  headerData.parsedBlockHeader.previousblockhash = addHexPrefix(headerData.parsedBlockHeader.previousblockhash);
  headerData.parsedBlockHeader.nextblockhash = addHexPrefix(headerData.parsedBlockHeader.previousblockhash);
  headerData.parsedBlockHeader.merkleroot = addHexPrefix(headerData.parsedBlockHeader.merkleroot);
  headerData.parsedBlockHeader.bits = addHexPrefix(headerData.parsedBlockHeader.bits);
  headerData.parsedBlockHeader.chainwork = addHexPrefix(headerData.parsedBlockHeader.chainwork);

  return headerData;
}

function addHexPrefix(str: string): string {
  return `0x${str}`;
}
