// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CoveToken } from "cove-contracts-boosties/src/governance/CoveToken.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { CoveYearnGaugeFactory } from "lib/cove-contracts-boosties/src/registries/CoveYearnGaugeFactory.sol";
import { YearnStakingDelegate } from "lib/cove-contracts-boosties/src/YearnStakingDelegate.sol";
import { TimelockController } from
    "lib/cove-contracts-boosties/lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";

contract Script is CommunityMultisigScript, StdAssertions {
    function run(bool shouldSend) public override {
        super.run(shouldSend);

        address coveYearnGaugeFactory = deployer.getAddress("CoveYearnGaugeFactory");
        address yearnStakingDelegate = deployer.getAddress("YearnStakingDelegate");
        address timelock = deployer.getAddress("TimelockController");

        CoveYearnGaugeFactory.GaugeInfo[] memory gauges =
            CoveYearnGaugeFactory(coveYearnGaugeFactory).getAllGaugeInfo(100, 0);

        // ================================ START BATCH ===================================
        address[] memory targets = new address[](gauges.length);
        uint256[] memory values = new uint256[](gauges.length);
        bytes[] memory payloads = new bytes[](gauges.length);

        for (uint256 i = 0; i < gauges.length; i++) {
            CoveYearnGaugeFactory.GaugeInfo memory gauge = gauges[i];
            targets[i] = yearnStakingDelegate;
            payloads[i] = abi.encodeCall(YearnStakingDelegate.setDepositLimit, (gauge.yearnGauge, type(uint256).max));
        }

        addToBatch(
            timelock,
            0,
            abi.encodeCall(
                TimelockController.scheduleBatch, (targets, values, payloads, bytes32(0), bytes32(0), 2 days)
            )
        );

        // ============================= TESTING ===================================
        // Warp to end of timelock period
        vm.warp(block.timestamp + 2 days);

        // Execute timelock
        vm.prank(MAINNET_COVE_DEPLOYER);
        TimelockController(payable(timelock)).executeBatch(targets, values, payloads, bytes32(0), bytes32(0));

        // Check for status after executing batch
        for (uint256 i = 0; i < gauges.length; i++) {
            CoveYearnGaugeFactory.GaugeInfo memory gauge = gauges[i];
            require(
                YearnStakingDelegate(yearnStakingDelegate).depositLimit(gauge.yearnGauge) == type(uint256).max,
                "deposit limit is not set"
            );
        }
        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true);
        }
    }
}
