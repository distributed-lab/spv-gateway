import { Deployer, Reporter } from "@solarity/hardhat-migrate";

import { SPVContract__factory } from "@ethers-v6";

import { getConfig } from "./config/config";

export = async (deployer: Deployer) => {
  const config = (await getConfig())!;

  const spvContract = await deployer.deploy(SPVContract__factory);

  await spvContract.__SPVContract_init(config.pendingBlockCount, config.pendingTargetHeightCount);

  Reporter.reportContracts(["SPVContract", await spvContract.getAddress()]);
};
