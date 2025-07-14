import { BigNumberish } from "ethers";

export type DeployConfig = {
  blockHeader: string;
  blockHeight: BigNumberish;
  cumulativeWork: BigNumberish;
};
