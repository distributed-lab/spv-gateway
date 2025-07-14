import axios from "axios";
import fsExtra from "fs-extra";

import { BlockHeaderData, ParsedBlockHeaderData } from "../../../test/helpers/types";
import path from "path";

interface RpcRequest {
  jsonrpc: string;
  id: string;
  method: string;
  params?: any[];
}

interface ChainTip {
  height: number;
  hash: string;
  branchlen: number;
  status: string;
}

class BitcoinRpcClient {
  private url: string;
  private auth: string;

  constructor(rpcUrl: string, rpcUser: string, rpcPassword: string) {
    this.url = rpcUrl;
    this.auth = "Basic " + Buffer.from(`${rpcUser}:${rpcPassword}`).toString("base64");
  }

  async callRpc<T>(method: string, params: any[] = []): Promise<T> {
    const request: RpcRequest = {
      jsonrpc: "1.0",
      id: "ts-script",
      method,
      params,
    };
    const response = await axios.post(this.url, request, {
      headers: { Authorization: this.auth },
    });
    if (response.data.error) {
      throw new Error(response.data.error.message);
    }
    return response.data.result as T;
  }
}

async function getBlockHeader(client: BitcoinRpcClient, hash: string): Promise<ParsedBlockHeaderData> {
  return await client.callRpc<ParsedBlockHeaderData>("getblockheader", [hash, true]);
}

async function getBlockHeaderRaw(client: BitcoinRpcClient, hash: string): Promise<string> {
  return await client.callRpc<string>("getblockheader", [hash, false]);
}

async function getChainTips(client: BitcoinRpcClient): Promise<ChainTip[]> {
  return await client.callRpc<ChainTip[]>("getchaintips");
}

async function main() {
  const rpcUrl = "http://127.0.0.1:18445/";
  const rpcUser = "admin1";
  const rpcPassword = "123";

  const client = new BitcoinRpcClient(rpcUrl, rpcUser, rpcPassword);

  const blocksData: {
    mainchainHeaders: BlockHeaderData[];
    forkChainHeaders: BlockHeaderData[];
  } = {
    mainchainHeaders: [],
    forkChainHeaders: [],
  };

  const chainTips = await getChainTips(client);
  const mainTip = chainTips.find((tip) => tip.status === "active");

  if (!mainTip) {
    console.error("Main chain tip not found");
    return;
  }

  let currentHash = mainTip.hash;
  let nextHash = currentHash;

  for (let i = 0; i < mainTip.height; i++) {
    const headerParsed = await getBlockHeader(client, currentHash);
    const headerRaw = await getBlockHeaderRaw(client, currentHash);

    blocksData.mainchainHeaders.push({
      blockHash: currentHash,
      rawHeader: headerRaw,
      height: headerParsed.height,
      parsedBlockHeader: {
        ...headerParsed,
        nextblockhash: nextHash,
      },
    });

    if (!headerParsed.previousblockhash) break;
    nextHash = currentHash;
    currentHash = headerParsed.previousblockhash;
  }

  const altTips = chainTips.filter((tip) => tip.status !== "active" && tip.status !== "invalid");

  for (const tip of altTips) {
    let altHash = tip.hash;
    let nextAltHash = altHash;

    for (let i = 0; i < tip.branchlen; i++) {
      const headerParsed = await getBlockHeader(client, altHash);
      const headerRaw = await getBlockHeaderRaw(client, altHash);

      blocksData.forkChainHeaders.push({
        blockHash: altHash,
        rawHeader: headerRaw,
        height: headerParsed.height,
        parsedBlockHeader: {
          ...headerParsed,
          nextblockhash: nextAltHash,
        },
      });

      if (!headerParsed.previousblockhash) break;
      altHash = headerParsed.previousblockhash;
    }
  }

  blocksData.mainchainHeaders.sort((a, b) => {
    return Number(BigInt(a.height) - BigInt(b.height));
  });
  blocksData.forkChainHeaders.sort((a, b) => {
    return Number(BigInt(a.height) - BigInt(b.height));
  });

  fsExtra.writeJSONSync(path.join(__dirname, "blocks_data.json"), blocksData);
}

main().catch(console.error);
