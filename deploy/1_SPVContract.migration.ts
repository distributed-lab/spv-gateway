import { Deployer, Reporter } from "@solarity/hardhat-migrate";

import { SPVContract__factory } from "@ethers-v6";

import { getConfig } from "./config/config";

export = async (deployer: Deployer) => {
  const config = (await getConfig())!;

  const spvContract = await deployer.deploy(SPVContract__factory);

  await spvContract["__SPVContract_init(bytes,uint256,uint256)"](
    config.blockHeader,
    config.blockHeight,
    config.cumulativeWork,
  );

  Reporter.reportContracts(["SPVContract", await spvContract.getAddress()]);
};
