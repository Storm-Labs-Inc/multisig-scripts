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
        CoveYearnGaugeFactory.GaugeInfo[] memory info = factory.getAllGaugeInfo(100, 0);
        uint256 totalRewardsToDistribute = 3_500_000 ether;
        // Skip ahead to to end of current reward period
        // vm.warp((ERC20RewardsGauge(coveYfiRewardsGauge).getRewardData(coveToken)).periodFinish + 1);

        // queueing up the rewards for epoch 4, week 1
        // https://docs.cove.finance/ecosystem/token/liquidity-mining#epoch-4
        // The following indexes correspond to the gauges entry in the factory.getAllGaugeInfo call
        // 0: Curve yEth (v2) 150,000 / 4 $COVE
        // 1: Curve YFI-ETH (v2) 150,000 / 4 $COVE
        // 2: Curve dYFIETH-f (v2)	100,000 / 4 $COVE
        // 3: LP Yearn CRV (v2) 350,000 / 4 $COVE
        // 4: LP Yearn PRISMA (v2) 50,000 / 4 $COVE
        // 5: USDC (v3)	550,000 / 4 $COVE
        // 6: DAI (v3)	400,000 / 4 $COVE
        // 7: WETH (v3)	100,000 $COVE
        // 8: coveYFI/YFI 200,000 / 4 $COVE
        // 9: DAI-2 200,000 / 4 $COVE
        // 10: WETH-2 200,000 / 4 $COVE
        // 11: crvUSD-2 200,000 / 4 $COVE
        // $coveYFI	850,000 / 4 $COVE

        uint256[] memory rewardAmounts = new uint256[](12);
        rewardAmounts[0] = 150_000 ether;
        rewardAmounts[1] = 150_000 ether;
        rewardAmounts[2] = 100_000 ether;
        rewardAmounts[3] = 350_000 ether;
        rewardAmounts[4] = 50_000 ether;
        rewardAmounts[5] = 550_000 ether;
        rewardAmounts[6] = 400_000 ether;
        rewardAmounts[7] = 100_000 ether;
        rewardAmounts[8] = 200_000 ether;
        rewardAmounts[9] = 200_000 ether;
        rewardAmounts[10] = 200_000 ether;
        rewardAmounts[11] = 200_000 ether;
        uint256 coveYFIRewardAmount = 850_000 ether;
        uint256 totalRewardsDistributed = coveYFIRewardAmount;
        uint256 balanceBefore = IERC20(coveToken).balanceOf(coveYfiRewardsGauge);
        addToBatch(
            coveToken,
            0,
            abi.encodeCall(IERC20.transfer, (coveYfiRewardsGaugeRewardForwarder, uint256(coveYFIRewardAmount) / 4))
        );
        addToBatch(
            coveYfiRewardsGaugeRewardForwarder, 0, abi.encodeCall(RewardForwarder.forwardRewardToken, (coveToken))
        );
        require(
            IERC20(coveToken).balanceOf(coveYfiRewardsGauge) == balanceBefore + uint256(coveYFIRewardAmount) / 4,
            "coveYfiRewardsGauge forwardRewardToken failed"
        );
        for (uint256 j = 0; j < info.length; j++) {
            uint256 rewardAmount = rewardAmounts[j];
            address autoCompoundingGaugeRewardForwarder =
                ERC20RewardsGauge(info[j].autoCompoundingGauge).getRewardData(address(coveToken)).distributor;
            // console.log("Queueing up rewards for gauge", info[j].autoCompoundingGauge);
            // uint256 balanceBefore = IERC20(coveToken).balanceOf(info[j].autoCompoundingGauge);
            addToBatch(
                coveToken, 0, abi.encodeCall(IERC20.transfer, (autoCompoundingGaugeRewardForwarder, rewardAmount / 4))
            );
            addToBatch(
                autoCompoundingGaugeRewardForwarder, 0, abi.encodeCall(RewardForwarder.forwardRewardToken, (coveToken))
            );
            // uint256 balanceAfter = IERC20(coveToken).balanceOf(info[j].autoCompoundingGauge);
            // require(balanceAfter == balanceBefore + rewardAmount / 4, "forwardRewardToken failed for gauge");
            // totalRewardsDistributed += rewardAmount;
            // console.log(
            //     "New rate: ", ERC20RewardsGauge(info[j].autoCompoundingGauge).getRewardData(address(coveToken)).rate
            // );
        }
        require(totalRewardsDistributed == totalRewardsToDistribute, "incorrect total rewards distributed");
        // Execute batch
        if (shouldSend) executeBatch(true);
    }
}
