import { SPVGateway__factory, ICreateX } from "@/generated-types/ethers";

import { ethers } from "hardhat";

export async function getSPVGatewayAddr(createXDeployer: ICreateX): Promise<string> {
  const salt = getSPVGatewaySalt();
  const guardedSalt = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(["bytes32"], [salt]));

  const initcodeHash = ethers.keccak256(SPVGateway__factory.bytecode);

  return await createXDeployer.computeCreate2Address(guardedSalt, initcodeHash);
}

export function getSPVGatewaySalt(): string {
  return `0x0000000000000000000000000000000000000000000012341234123412341231`;
}
