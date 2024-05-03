// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { RewardForwarder } from "cove-contracts-boosties/src/rewards/RewardForwarder.sol";
import { ERC20RewardsGauge } from "cove-contracts-boosties/src/rewards/ERC20RewardsGauge.sol";
import { CoveYearnGaugeFactory } from "cove-contracts-boosties/src/registries/CoveYearnGaugeFactory.sol";
import { CoveToken } from "cove-contracts-boosties/src/governance/CoveToken.sol";
import { console2 as console } from "forge-std/Console2.sol";
import { OpsMultisigScript } from "./OpsMultisigScript.s.sol";

contract Script is OpsMultisigScript {
    function run(bool shouldSend) public override {
        super.run(shouldSend);

        address coveToken = deployer.getAddress("CoveToken");
        address coveYfiRewardsGauge = deployer.getAddress("CoveYfiRewardsGauge");
        address coveYfiRewardsGaugeRewardForwarder = deployer.getAddress("CoveYFIRewardsGaugeRewardForwarder");
        CoveYearnGaugeFactory factory = CoveYearnGaugeFactory(deployer.getAddress("CoveYearnGaugeFactory"));
        CoveYearnGaugeFactory.GaugeInfo[] memory info = factory.getAllGaugeInfo(8, 0);
        // Skip ahead to to end of current reward period
        vm.warp((ERC20RewardsGauge(coveYfiRewardsGauge).getRewardData(coveToken)).periodFinish + 1);

        // queueing up the rewards for epoch 1, week 1
        // 3.5M / 3 COVE to CoveYFIRewardsGauge
        // (750K / 5) / 3 COVE to each V2 auto-compoiunding gauge
        // (750k / 3) / 3 COVE to each V3 auto-compounding gauge
        uint256 balanceBefore = IERC20(coveToken).balanceOf(coveYfiRewardsGauge);
        addToBatch(
            coveToken,
            0,
            abi.encodeCall(IERC20.transfer, (coveYfiRewardsGaugeRewardForwarder, uint256(3_500_000 ether) / 3))
        );
        addToBatch(
            coveYfiRewardsGaugeRewardForwarder, 0, abi.encodeCall(RewardForwarder.forwardRewardToken, (coveToken))
        );
        require(
            IERC20(coveToken).balanceOf(coveYfiRewardsGauge) == balanceBefore + uint256(3_500_000 ether) / 3,
            "coveYfiRewardsGauge forwardRewardToken failed"
        );

        for (uint256 j = 0; j < info.length; j++) {
            uint256 rewardSplitAmount = info[j].isVaultV2 ? 5 : 3;
            address autoCompoundingGaugeRewardForwarder =
                ERC20RewardsGauge(info[j].autoCompoundingGauge).getRewardData(address(coveToken)).distributor;
            console.log("Queueing up rewards for gauge", info[j].autoCompoundingGauge);
            uint256 balanceBefore = IERC20(coveToken).balanceOf(info[j].autoCompoundingGauge);
            addToBatch(
                coveToken,
                0,
                abi.encodeCall(
                    IERC20.transfer,
                    (autoCompoundingGaugeRewardForwarder, (uint256(750_000 ether) / rewardSplitAmount) / 3)
                )
            );
            addToBatch(
                autoCompoundingGaugeRewardForwarder, 0, abi.encodeCall(RewardForwarder.forwardRewardToken, (coveToken))
            );
            require(
                IERC20(coveToken).balanceOf(info[j].autoCompoundingGauge)
                    == balanceBefore + (uint256(750_000 ether) / rewardSplitAmount) / 3,
                "forwardRewardToken failed for v2 auto-compounding gauge"
            );
            console.log(
                "New rate: ", ERC20RewardsGauge(info[j].autoCompoundingGauge).getRewardData(address(coveToken)).rate
            );
        }
        // Execute batch
        if (shouldSend) executeBatch(true);
    }
}
