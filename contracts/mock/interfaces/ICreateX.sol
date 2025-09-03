// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ICreateX {
    struct Values {
        uint256 constructorAmount;
        uint256 initCallAmount;
    }

    function deployCreate2AndInit(
        bytes32 salt_,
        bytes memory initCode_,
        bytes memory data_,
        Values memory values_
    ) external payable returns (address newContract_);

    function computeCreate2Address(
        bytes32 salt_,
        bytes32 initCodeHash_
    ) external view returns (address computedAddress_);
}
