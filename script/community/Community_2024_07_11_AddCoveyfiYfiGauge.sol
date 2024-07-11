// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { YearnStakingDelegate } from "cove-contracts-boosties/src/YearnStakingDelegate.sol";
import { CoveYearnGaugeFactory } from "cove-contracts-boosties/src/registries/CoveYearnGaugeFactory.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { CoveToken } from "cove-contracts-boosties/src/governance/CoveToken.sol";

contract Script is CommunityMultisigScript, StdAssertions {
    function run(bool shouldSend) public override {
        super.run(shouldSend);
        uint256 totalRewards = 4_000_000 ether;
        address yearnStakingDelegate = deployer.getAddress("YearnStakingDelegate");
        address coveYearnGaugeFactory = deployer.getAddress("CoveYearnGaugeFactory");
        address stakingDelegateRewards = deployer.getAddress("StakingDelegateRewards");
        address newStrategy = deployer.getAddress("YearnGaugeStrategy-yGauge Curve COVEYFI Factory yVault");
        address timelock = deployer.getAddress("TimelockController");
        CoveToken coveToken = CoveToken(deployer.getAddress("CoveToken"));

        // ================================ START BATCH ===================================
        // Add to batch
        addToBatch(
            yearnStakingDelegate,
            0,
            abi.encodeCall(YearnStakingDelegate.addGaugeRewards, (MAINNET_COVEYFI_YFI_GAUGE, stakingDelegateRewards))
        );
        addToBatch(coveYearnGaugeFactory, 0, abi.encodeCall(CoveYearnGaugeFactory.deployCoveGauges, (newStrategy)));

        CoveYearnGaugeFactory.GaugeInfo memory info =
            CoveYearnGaugeFactory(coveYearnGaugeFactory).getGaugeInfo(yearnGauge);

        address autoCompoundingGaugeRewardForwarder =
            ERC20RewardsGauge(info.autoCompoundingGauge).getRewardData(address(coveToken)).distributor;
        address nonComoundingGaugeRewardForwarder =
            ERC20RewardsGauge(info.nonAutoCompoundingGauge).getRewardData(address(coveToken)).distributor;

        addToBatch(
            autoCompoundingGaugeRewardForwarder,
            0,
            abi.encodeCall(YearnStakingDelegate.grantRole, (MANAGER_ROLE, MAINNET_DEFENDER_RELAYER))
        );
        addToBatch(
            nonComoundingGaugeRewardForwarder,
            0,
            abi.encodeCall(YearnStakingDelegate.grantRole, (MANAGER_ROLE, MAINNET_DEFENDER_RELAYER))
        );

        address[] memory targets = new address[](7);
        uint256[] memory values = new uint256[](7);
        bytes[] memory payloads = new bytes[](7);

        // Grant depositor role to the strategy and the ysd rewards gauge
        targets[0] = yearnStakingDelegate;
        payloads[0] = abi.encodeCall(YearnStakingDelegate.grantRole, (DEPOSITOR_ROLE, info.coveYearnStrategy));
        targets[1] = yearnStakingDelegate;
        payloads[1] = abi.encodeCall(YearnStakingDelegate.grantRole, (DEPOSITOR_ROLE, info.nonAutoCompoundingGauge));
        targets[2] = yearnStakingDelegate;
        payloads[2] = abi.encodeCall(
            YearnStakingDelegate.setDepositLimit, (MAINNET_COVEYFI_YFI_GAUGE, uint256(100_000e18 * 1e18) / 4529.94e18)
        );
        require(coveToken.allowedSender(info.autoCompoundingGauge) == false, "Already allowed sender");
        require(coveToken.allowedSender(info.nonAutoCompoundingGauge) == false, "Already allowed sender");
        require(coveToken.allowedSender(autoCompoundingGaugeRewardForwarder) == false, "Already allowed sender");
        require(coveToken.allowedSender(nonComoundingGaugeRewardForwarder) == false, "Already allowed sender");
        targets[3] = coveToken;
        payloads[3] = abi.encodeCall(coveToken.addAllowedSender, (info.autoCompoundingGauge));
        targets[4] = coveToken;
        payloads[4] = abi.encodeCall(coveToken.addAllowedSender, (info.nonAutoCompoundingGauge));
        targets[5] = coveToken;
        payloads[5] = abi.encodeCall(coveToken.addAllowedSender, (autoCompoundingGaugeRewardForwarder));
        targets[6] = coveToken;
        payloads[6] = abi.encodeCall(coveToken.addAllowedSender, (nonComoundingGaugeRewardForwarder));

        addToBatch(
            timelock,
            0,
            abi.encodeCall(TimelockController.scheduleBatch, (targets, values, paylods, bytes32(0), bytes32(0), 2 days))
        );

        // ================================ TESTING ===================================

        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true);
        }
    }
}
