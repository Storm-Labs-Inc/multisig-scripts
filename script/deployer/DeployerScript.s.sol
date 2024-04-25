// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";
import { Constants } from "cove-contracts-boosties/test/utils/Constants.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../ReadOnlyDeployer.s.sol";

abstract contract DeployerScript is Script, Constants {
    ReadOnlyDeployer public deployer;

    function run() public virtual {
        deployer = getDeployer();
        // Example
        // contract.method();
    }
}
