import { BigNumberish } from "ethers";

export type ReorgBlocksData = {
  mainchainHeaders: BlockHeaderData[];
  forkChainHeaders: BlockHeaderData[];
};

export type BlockHeaderData = {
  height: BigNumberish;
  blockHash: string;
  rawHeader: string;
  parsedBlockHeader: ParsedBlockHeaderData;
};

export type ParsedBlockHeaderData = {
  hash: string;
  confirmations: BigNumberish;
  height: BigNumberish;
  version: BigNumberish;
  versionHex: BigNumberish;
  merkleroot: string;
  time: BigNumberish;
  mediantime: BigNumberish;
  nonce: BigNumberish;
  bits: string;
  difficulty: BigNumberish;
  chainwork: string;
  nTx: BigNumberish;
  previousblockhash: string;
  nextblockhash: string;
};

export enum BlockStatus {
  Unknown = 0,
  Pending = 1,
  Stale = 2,
  Confirmed = 3,
}
