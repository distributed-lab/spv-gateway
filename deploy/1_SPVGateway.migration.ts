import { Deployer, Reporter } from "@solarity/hardhat-migrate";

import { SPVGateway__factory, ICreateX__factory } from "@ethers-v6";

import { getConfig } from "./config/config";
import { getSPVGatewayAddr, getSPVGatewaySalt } from "./helpers/helpers";

export = async (deployer: Deployer) => {
  const config = await getConfig();

  const createXDeployer = await deployer.deployed(ICreateX__factory, "0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed");

  const salt = getSPVGatewaySalt();
  const initCalldata = SPVGateway__factory.createInterface().encodeFunctionData(
    "__SPVGateway_init(bytes,uint64,uint256)",
    [config.blockHeader, config.blockHeight, config.cumulativeWork],
  );

  await createXDeployer.deployCreate2AndInit(salt, SPVGateway__factory.bytecode, initCalldata, {
    constructorAmount: 0n,
    initCallAmount: 0n,
  });

  const spvGatewayAddr = await getSPVGatewayAddr(createXDeployer);

  Reporter.reportContracts(["SPVGateway", spvGatewayAddr]);
};
