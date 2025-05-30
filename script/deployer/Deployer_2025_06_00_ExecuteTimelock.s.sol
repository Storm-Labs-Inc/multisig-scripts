// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CoveToken } from "cove-contracts-boosties/src/governance/CoveToken.sol";
import { DeployerScript } from "./DeployerScript.s.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { YearnStakingDelegate } from "cove-contracts-boosties/src/YearnStakingDelegate.sol";
import { CoveYearnGaugeFactory } from "cove-contracts-boosties/src/registries/CoveYearnGaugeFactory.sol";
import { ERC20RewardsGauge } from "cove-contracts-boosties/src/rewards/ERC20RewardsGauge.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Yearn4626RouterExt } from "cove-contracts-boosties/src/Yearn4626RouterExt.sol";
import { PeripheryPayments } from
    "lib/cove-contracts-boosties/lib/Yearn-ERC4626-Router/src/external/PeripheryPayments.sol";

contract Script is DeployerScript {
    address public coveUSDFarmingPlugin = 0xa74e0B738b053D9083451bBAB84c538ff2Cc701d;

    function run() public override {
        super.run();
        vm.startBroadcast(MAINNET_COVE_DEPLOYER);

        address coveToken = deployer.getAddress("CoveToken");

        // ================================ START BATCH ===================================

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory payloads = new bytes[](1);

        // Add farming plugin to allowed senders
        targets[0] = coveToken;
        payloads[0] = abi.encodeCall(CoveToken.addAllowedSender, (coveUSDFarmingPlugin));

        TimelockController(payable(timelock)).executeBatch(targets, values, payloads, bytes32(0), bytes32(0));

        // ============================= TESTING ===================================
        require(CoveToken(coveToken).allowedSender(coveUSDFarmingPlugin), "farmingPlugin is not allowed to send");
    }
}
