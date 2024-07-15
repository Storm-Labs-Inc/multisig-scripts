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
        // vm.warp((ERC20RewardsGauge(coveYfiRewardsGauge).getRewardData(coveToken)).periodFinish + 1);

        // queueing up the rewards for epoch 3, week 1
        // https://docs.cove.finance/ecosystem/token/liquidity-mining#epoch-3
        // The following indexes correspond to the gauges entry in the factory.getAllGaugeInfo call
        // 0: Curve yEth (v2) 150,000 / 4 $COVE
        // 1: Curve YFI-ETH (v2) 150,000 / 4 $COVE
        // 2: Curve dYFIETH-f (v2)	100,000 / 4 $COVE
        // 3: LP Yearn CRV (v2) 100,000 / 4 $COVE
        // 4: LP Yearn PRISMA (v2) 100,000 / 4 $COVE
        // 5: USDC (v3)	500,000 / 4 $COVE
        // 6: DAI (v3)	600,000 / 4 $COVE
        // 7: WETH (v3)	100,000 $COVE
        // 8: coveYFI/YFI 600,000 / 4 $COVE
        // $coveYFI	1,600,000 / 4 $COVE

        uint256[] memory rewardAmounts = new uint256[](9);
        rewardAmounts[0] = 150_000 ether;
        rewardAmounts[1] = 150_000 ether;
        rewardAmounts[2] = 100_000 ether;
        rewardAmounts[3] = 100_000 ether;
        rewardAmounts[4] = 100_000 ether;
        rewardAmounts[5] = 500_000 ether;
        rewardAmounts[6] = 600_000 ether;
        rewardAmounts[7] = 100_000 ether;
        rewardAmounts[8] = 600_000 ether;
        uint256 balanceBefore = IERC20(coveToken).balanceOf(coveYfiRewardsGauge);
        addToBatch(
            coveToken,
            0,
            abi.encodeCall(IERC20.transfer, (coveYfiRewardsGaugeRewardForwarder, uint256(1_600_000 ether) / 4))
        );
        addToBatch(
            coveYfiRewardsGaugeRewardForwarder, 0, abi.encodeCall(RewardForwarder.forwardRewardToken, (coveToken))
        );
        require(
            IERC20(coveToken).balanceOf(coveYfiRewardsGauge) == balanceBefore + uint256(1_600_000 ether) / 4,
            "coveYfiRewardsGauge forwardRewardToken failed"
        );

        for (uint256 j = 0; j < info.length; j++) {
            uint256 rewardAmount = rewardAmounts[j];
            address autoCompoundingGaugeRewardForwarder =
                ERC20RewardsGauge(info[j].autoCompoundingGauge).getRewardData(address(coveToken)).distributor;
            console.log("Queueing up rewards for gauge", info[j].autoCompoundingGauge);
            uint256 balanceBefore = IERC20(coveToken).balanceOf(info[j].autoCompoundingGauge);
            addToBatch(
                coveToken, 0, abi.encodeCall(IERC20.transfer, (autoCompoundingGaugeRewardForwarder, rewardAmount / 4))
            );
            addToBatch(
                autoCompoundingGaugeRewardForwarder, 0, abi.encodeCall(RewardForwarder.forwardRewardToken, (coveToken))
            );
            require(
                IERC20(coveToken).balanceOf(info[j].autoCompoundingGauge) == balanceBefore + rewardAmount / 4,
                "forwardRewardToken failed for gauge"
            );
            console.log(
                "New rate: ", ERC20RewardsGauge(info[j].autoCompoundingGauge).getRewardData(address(coveToken)).rate
            );
        }
        // Execute batch
        if (shouldSend) executeBatch(true);
    }
}
