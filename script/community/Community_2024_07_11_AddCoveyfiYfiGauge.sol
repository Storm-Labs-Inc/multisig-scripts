// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { YearnStakingDelegate } from "cove-contracts-boosties/src/YearnStakingDelegate.sol";
import { CoveYearnGaugeFactory } from "cove-contracts-boosties/src/registries/CoveYearnGaugeFactory.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { CoveToken } from "cove-contracts-boosties/src/governance/CoveToken.sol";
import { ERC20RewardsGauge } from "cove-contracts-boosties/src/rewards/ERC20RewardsGauge.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract Script is CommunityMultisigScript, StdAssertions {
    function run(bool shouldSend) public override {
        super.run(shouldSend);
        uint256 totalRewards = 4_000_000 ether;
        address yearnStakingDelegate = deployer.getAddress("YearnStakingDelegate");
        address coveYearnGaugeFactory = deployer.getAddress("CoveYearnGaugeFactory");
        address stakingDelegateRewards = deployer.getAddress("StakingDelegateRewards");
        address newStrategy = deployer.getAddress("YearnGaugeStrategy-yGauge Curve COVEYFI Factory yVault");
        address timelock = deployer.getAddress("TimelockController");
        // 100k USD deposit limit with 4529.94 USD per COVEYFI/YFI LP token
        uint256 maxDeposit = uint256(100_000e18 * 1e18) / 4529.94e18;
        CoveToken coveToken = CoveToken(deployer.getAddress("CoveToken"));

        // ================================ START BATCH ===================================
        // Add to batch
        // Add coveyfi yfi gauge to YSD
        addToBatch(
            yearnStakingDelegate,
            0,
            abi.encodeCall(YearnStakingDelegate.addGaugeRewards, (MAINNET_COVEYFI_YFI_GAUGE, stakingDelegateRewards))
        );
        // Deploy the reward gauges and the forwarders via the factory
        addToBatch(coveYearnGaugeFactory, 0, abi.encodeCall(CoveYearnGaugeFactory.deployCoveGauges, (newStrategy)));

        CoveYearnGaugeFactory.GaugeInfo memory info =
            CoveYearnGaugeFactory(coveYearnGaugeFactory).getGaugeInfo(MAINNET_COVEYFI_YFI_GAUGE);

        address autoCompoundingGaugeRewardForwarder =
            ERC20RewardsGauge(info.autoCompoundingGauge).getRewardData(address(coveToken)).distributor;
        address nonComoundingGaugeRewardForwarder =
            ERC20RewardsGauge(info.nonAutoCompoundingGauge).getRewardData(address(coveToken)).distributor;

        // Grant manager role to the relayer for reward forwarding
        addToBatch(
            autoCompoundingGaugeRewardForwarder,
            0,
            abi.encodeCall(AccessControl.grantRole, (MANAGER_ROLE, MAINNET_DEFENDER_RELAYER))
        );
        // Grant manager role to the relayer for reward forwarding
        addToBatch(
            nonComoundingGaugeRewardForwarder,
            0,
            abi.encodeCall(AccessControl.grantRole, (MANAGER_ROLE, MAINNET_DEFENDER_RELAYER))
        );

        address[] memory targets = new address[](8);
        uint256[] memory values = new uint256[](8);
        bytes[] memory payloads = new bytes[](8);

        // Grant depositor role to the strategy and non-auto compounding gauge
        targets[0] = yearnStakingDelegate;
        payloads[0] = abi.encodeCall(AccessControl.grantRole, (DEPOSITOR_ROLE, info.coveYearnStrategy));
        targets[1] = yearnStakingDelegate;
        payloads[1] = abi.encodeCall(AccessControl.grantRole, (DEPOSITOR_ROLE, info.nonAutoCompoundingGauge));
        // Set deposit limit for the gauge
        targets[2] = yearnStakingDelegate;
        payloads[2] = abi.encodeCall(YearnStakingDelegate.setDepositLimit, (MAINNET_COVEYFI_YFI_GAUGE, maxDeposit));
        require(coveToken.allowedSender(info.autoCompoundingGauge) == false, "Already allowed sender");
        require(coveToken.allowedSender(info.nonAutoCompoundingGauge) == false, "Already allowed sender");
        require(coveToken.allowedSender(autoCompoundingGaugeRewardForwarder) == false, "Already allowed sender");
        require(coveToken.allowedSender(nonComoundingGaugeRewardForwarder) == false, "Already allowed sender");
        // Add COVE's allowed sender for the gauges and the forwarders
        targets[3] = address(coveToken);
        payloads[3] = abi.encodeCall(coveToken.addAllowedSender, (info.autoCompoundingGauge));
        targets[4] = address(coveToken);
        payloads[4] = abi.encodeCall(coveToken.addAllowedSender, (info.nonAutoCompoundingGauge));
        targets[5] = address(coveToken);
        payloads[5] = abi.encodeCall(coveToken.addAllowedSender, (autoCompoundingGaugeRewardForwarder));
        targets[6] = address(coveToken);
        payloads[6] = abi.encodeCall(coveToken.addAllowedSender, (nonComoundingGaugeRewardForwarder));
        // Set the gauge reward split for covyfi yfi gauge
        targets[7] = address(yearnStakingDelegate);
        payloads[7] =
            abi.encodeCall(YearnStakingDelegate.setGaugeRewardSplit, (MAINNET_COVEYFI_YFI_GAUGE, 5e17, 0, 90e17, 5e17));

        // Queue up the timelock transaction
        addToBatch(
            timelock,
            0,
            abi.encodeCall(
                TimelockController.scheduleBatch, (targets, values, payloads, bytes32(0), bytes32(0), 2 days)
            )
        );

        // ================================ TESTING ===================================
        // Skip ahead to end of timelock period to execute batch
        vm.warp(block.timestamp + 2 days + 1);
        vm.prank(MAINNET_COVE_DEPLOYER);
        TimelockController(payable(timelock)).executeBatch(targets, values, payloads, bytes32(0), bytes32(0));

        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true);
        }
    }
}
