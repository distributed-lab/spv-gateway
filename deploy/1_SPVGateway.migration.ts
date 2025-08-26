import { Deployer, Reporter } from "@solarity/hardhat-migrate";

import { SPVGateway__factory } from "@ethers-v6";

import { getConfig } from "./config/config";

export = async (deployer: Deployer) => {
  const config = (await getConfig())!;

  const spvGateway = await deployer.deploy(SPVGateway__factory);

  await spvGateway["__SPVGateway_init(bytes,uint256,uint256)"](
    config.blockHeader,
    config.blockHeight,
    config.cumulativeWork,
  );

  Reporter.reportContracts(["SPVGateway", await spvGateway.getAddress()]);
};
