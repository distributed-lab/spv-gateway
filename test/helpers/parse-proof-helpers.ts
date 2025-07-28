import { ZeroHash } from "ethers";

let hashes: string[];
let flagPath: string;
let maxDepth: number;
let nodeCountPerLevel: number[];

export function parseRawProof(txid: string, rawProof: string): [string, string[], string] {
  const txidReversed = reverseBytes(txid);
  const withoutHeader = rawProof.slice(160);

  const txCountOffset = 8;
  let offset = txCountOffset;

  const txCountRaw = withoutHeader.slice(0, offset);
  const txCountInBlock = parseInt(reverseBytes(txCountRaw), 16);
  const [hashCount, hashCountSize] = parseCuint(withoutHeader, offset);

  offset += hashCountSize;

  const rawHashes = withoutHeader.slice(offset, offset + hashCount * 64);

  hashes = [];
  for (let i = 0; i < hashCount; i++) {
    hashes.push("0x" + rawHashes.slice(i * 64, (i + 1) * 64));
  }

  offset = offset + hashCount * 64;

  const [byteFlagsCount, byteFlagsCountSize] = parseCuint(withoutHeader, offset);

  offset += byteFlagsCountSize;

  const byteFlags = withoutHeader.slice(offset, offset + 2 * byteFlagsCount);

  flagPath = processFlags(byteFlags);
  maxDepth = Math.ceil(Math.log2(txCountInBlock));
  nodeCountPerLevel = getNodeCountPerLevel(txCountInBlock, maxDepth);

  const [txIndex, sortedHashes] = processTree(0, 0, 0, 0, 0, []);

  let directions = getDirections(txIndex, txCountInBlock);

  return [txidReversed, sortedHashes, directions];
}

function reverseBytes(str: string) {
  if (str.slice(0, 2) == "0x") str = str.slice(2);

  return "0x" + Buffer.from(str, "hex").reverse().toString("hex");
}

function parseCuint(data: string, offset: number): [number, number] {
  const firstByte = parseInt(data.slice(offset, offset + 2), 16);

  if (firstByte < 0xfd) return [parseInt(data.slice(offset, offset + 2), 16), 2];
  if (firstByte == 0xfd) return [parseInt(data.slice(offset + 2, offset + 6), 16), 6];
  if (firstByte == 0xfe) return [parseInt(data.slice(offset + 2, offset + 10), 16), 10];
  return [parseInt(data.slice(offset + 2, offset + 18), 16), 18];
}

function processFlags(flagBytes: string): string {
  let directions = "";

  for (let i = 0; i < flagBytes.length; i += 2) {
    directions += reverseByte(flagBytes.substring(i, i + 2));
  }

  return directions;
}

function reverseByte(byte: string): string {
  const binary = parseInt(byte, 16).toString(2);
  const padded = binary.padStart(8, "0");
  return padded.split("").reverse().join("");
}

function getNodeCountPerLevel(txCount: number, depth: number): number[] {
  let result: number[] = [];
  let levelSize = txCount;

  for (let i = depth; i >= 0; i--) {
    result[depth] = levelSize;

    levelSize = Math.ceil(levelSize / 2);
    depth--;
  }

  return result;
}

function processTree(
  depth: number,
  currentFlag: number,
  txIndex: number,
  currentHash: number,
  nodePosition: number,
  sortedHashes: string[],
): [number, string[]] {
  if (depth == maxDepth && flagPath.at(currentFlag) == "1") {
    //this is the tx we searched for
    ++currentHash;

    if (isNodeWithoutPair(depth, nodePosition)) {
      sortedHashes.push(ZeroHash);
    } else if (isLastLeaf(nodePosition, currentHash)) {
      sortedHashes.push(hashes[currentHash]);
    }

    sortedHashes.reverse();

    return [txIndex, sortedHashes];
  }

  if (depth == maxDepth) {
    //this is neighbour of the tx we searched for
    sortedHashes.push(hashes[currentHash]);

    return processTree(depth, currentFlag + 1, txIndex + 1, currentHash + 1, nodePosition + 1, sortedHashes);
  }

  if (flagPath.at(currentFlag) == "1") {
    if (isNodeWithoutPair(depth, nodePosition)) {
      sortedHashes.push(ZeroHash);
    } else if (isLeftNode(depth, nodePosition)) {
      const rightNodeHash = hashes.pop();

      if (!rightNodeHash) throw Error(`No hashes left at depth ${depth}`);

      sortedHashes.push(rightNodeHash);
    }

    return processTree(depth + 1, currentFlag + 1, txIndex, currentHash, nodePosition * 2, sortedHashes);
  }

  const txSkipped = 2 ** (maxDepth - depth);

  sortedHashes.push(hashes[currentHash]);

  return processTree(depth, currentFlag + 1, txIndex + txSkipped, currentHash + 1, nodePosition + 1, sortedHashes);
}

function nodesCountIsUneven(level: number): boolean {
  return nodeCountPerLevel[level]! % 2 == 1;
}

function isNodeWithoutPair(depth: number, nodePosition: number): boolean {
  return depth != 0 && nodesCountIsUneven(depth) && nodePosition + 1 == nodeCountPerLevel[depth];
}

function isLeftNode(depth: number, nodePosition: number): boolean {
  return depth != 0 && nodePosition % 2 == 0;
}

function isLastLeaf(nodePosition: number, currentHash: number): boolean {
  return nodePosition % 2 == 0 && currentHash < hashes.length;
}

function getDirections(txIndex: number, totalTransactions: number) {
  let directions: string = "0x";
  let curIndex = txIndex;
  let levelSize = totalTransactions;

  while (levelSize > 1) {
    if (curIndex % 2 == 0) {
      if (levelSize % 2 == 1 && levelSize - 1 == curIndex) directions += "02";
      else directions += "00";
    } else directions += "01";

    curIndex = Math.floor(curIndex / 2);
    levelSize = Math.ceil(levelSize / 2);
  }

  return directions;
}
