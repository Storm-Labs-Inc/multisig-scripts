// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import {
    TimelockController
} from "lib/cove-contracts-boosties/lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";
import { CoveYearnGaugeFactory } from "lib/cove-contracts-boosties/src/registries/CoveYearnGaugeFactory.sol";
import { YearnStakingDelegate } from "lib/cove-contracts-boosties/src/YearnStakingDelegate.sol";
import { IYearnStakingDelegate } from "lib/cove-contracts-boosties/src/interfaces/IYearnStakingDelegate.sol";

contract Script is CommunityMultisigScript, StdAssertions {
    function run(bool shouldSend) public override {
        super.run(shouldSend);

        // Resolve deployed addresses
        address timelock = deployer.getAddress("TimelockController");
        address yearnStakingDelegate = deployer.getAddress("YearnStakingDelegate");
        address coveYearnGaugeFactory = deployer.getAddress("CoveYearnGaugeFactory");

        // Gather gauges (sufficiently high limit to include all)
        CoveYearnGaugeFactory.GaugeInfo[] memory gauges =
            CoveYearnGaugeFactory(coveYearnGaugeFactory).getAllGaugeInfo(200, 0);

        uint256 minDelay = TimelockController(payable(timelock)).getMinDelay();

        // Build timelock batch: first update splits for each gauge, then disable perpetual lock
        uint256 ops = gauges.length + 1;
        address[] memory targets = new address[](ops);
        uint256[] memory values = new uint256[](ops);
        bytes[] memory payloads = new bytes[](ops);

        // Step 1: Update reward split for each gauge to (0, 0, 1e18, 0)
        for (uint256 i = 0; i < gauges.length; i++) {
            targets[i] = yearnStakingDelegate;
            payloads[i] = abi.encodeCall(
                YearnStakingDelegate.setGaugeRewardSplit,
                (gauges[i].yearnGauge, uint64(0), uint64(0), uint64(1e18), uint64(0))
            );
        }

        // Step 2: Disable perpetual lock (set to false)
        targets[ops - 1] = yearnStakingDelegate;
        payloads[ops - 1] = abi.encodeCall(YearnStakingDelegate.setPerpetualLock, (false));

        // Schedule the batch on the timelock
        addToBatch(
            timelock,
            0,
            abi.encodeCall(
                TimelockController.scheduleBatch, (targets, values, payloads, bytes32(0), bytes32(0), minDelay)
            )
        );

        // ================================ TESTING (fork sim) ===================================
        // Warp forward past min delay and execute via deployer to validate effects
        vm.warp(block.timestamp + minDelay + 1);
        vm.prank(MAINNET_COVE_DEPLOYER);
        TimelockController(payable(timelock)).executeBatch(targets, values, payloads, bytes32(0), bytes32(0));

        // Validate: perpetual lock disabled
        bool lockStatus = YearnStakingDelegate(yearnStakingDelegate).shouldPerpetuallyLock();
        require(lockStatus == false, "perpetual lock should be disabled");

        // Validate: gauge splits set to (0, 0, 1e18, 0)
        for (uint256 i = 0; i < gauges.length; i++) {
            IYearnStakingDelegate.RewardSplit memory split =
                IYearnStakingDelegate(yearnStakingDelegate).getGaugeRewardSplit(gauges[i].yearnGauge);
            require(split.treasury == 0, "treasury pct != 0");
            require(split.coveYfi == 0, "coveYFI pct != 0");
            require(split.user == 1e18, "user pct != 1e18");
            require(split.lock == 0, "lock pct != 0");
        }

        // ============================= QUEUE UP MSIG ==========================================
        if (shouldSend) {
            executeBatch(true);
        }
    }
}
