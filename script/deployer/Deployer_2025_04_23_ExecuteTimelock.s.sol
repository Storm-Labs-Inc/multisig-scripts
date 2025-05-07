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
    function run() public override {
        super.run();
        vm.startBroadcast(MAINNET_COVE_DEPLOYER);

        address coveToken = deployer.getAddress("CoveToken");
        address timelock = deployer.getAddress("TimelockController");
        address ysd = deployer.getAddress("YearnStakingDelegate");
        address coveYearnGaugeFactory = deployer.getAddress("CoveYearnGaugeFactory");

        // ================================ START BATCH ===================================
        CoveYearnGaugeFactory.GaugeInfo[] memory gauges =
            CoveYearnGaugeFactory(coveYearnGaugeFactory).getAllGaugeInfo(100, 0);

        address[] memory targets = new address[](gauges.length);
        uint256[] memory values = new uint256[](gauges.length);
        bytes[] memory payloads = new bytes[](gauges.length);

        for (uint256 i = 0; i < gauges.length; i++) {
            targets[i] = ysd;
            payloads[i] =
                abi.encodeCall(YearnStakingDelegate.setDepositLimit, (gauges[i].yearnGauge, type(uint256).max));
        }

        TimelockController(payable(timelock)).executeBatch(targets, values, payloads, bytes32(0), bytes32(0));
    }
}
