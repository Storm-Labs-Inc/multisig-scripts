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
    address[][] public timelockTargets;
    uint256[][] public timelockValues;
    bytes[][] public timelockPayloads;

    uint64 public constant DEFAULT_TREASURY_PCT = 0;
    uint64 public constant DEFAULT_COVEYFI_PCT = 0.05e18;
    uint64 public constant DEFAULT_USER_PCT = 0.9e18;
    uint64 public constant DEFAULT_VEYFI_PCT = 0.05e18;

    address public coveYearnGaugeFactory;
    address public yearnStakingDelegate;
    address public stakingDelegateRewards;
    address public timelock;
    address public coveToken;

    function run(bool shouldSend) public override {
        super.run(shouldSend);
        yearnStakingDelegate = deployer.getAddress("YearnStakingDelegate");
        coveYearnGaugeFactory = deployer.getAddress("CoveYearnGaugeFactory");
        stakingDelegateRewards = deployer.getAddress("StakingDelegateRewards");
        address dai2 = deployer.getAddress("YearnGaugeStrategy-yGauge DAI-2 yVault");
        address weth2 = deployer.getAddress("YearnGaugeStrategy-yGauge WETH-2 yVault");
        address crvusd2 = deployer.getAddress("YearnGaugeStrategy-yGauge crvUSD-2 yVault");
        timelock = deployer.getAddress("TimelockController");
        coveToken = deployer.getAddress("CoveToken");
        // 100k USD deposit limit with 1 USD per DAI
        uint256 dai2MaxDeposit = 100_000e18;
        // 100k USD deposit limit with 3000 USD per WETH
        uint256 weth2MaxDeposit = uint256(100_000e18 * 1e18) / 3000e18;
        // 100k USD deposit limit with 1 USD per crvUSD
        uint256 crvusd2MaxDeposit = 100_000e18;

        // ================================ START BATCH ===================================
        _deployGaugesGrantRolesDepsoitLimitFeeSplit(
            MAINNET_YVDAI_2_GAUGE,
            dai2,
            dai2MaxDeposit,
            DEFAULT_TREASURY_PCT,
            DEFAULT_COVEYFI_PCT,
            DEFAULT_USER_PCT,
            DEFAULT_VEYFI_PCT
        );
        _deployGaugesGrantRolesDepsoitLimitFeeSplit(
            MAINNET_YVWETH_2_GAUGE,
            weth2,
            weth2MaxDeposit,
            DEFAULT_TREASURY_PCT,
            DEFAULT_COVEYFI_PCT,
            DEFAULT_USER_PCT,
            DEFAULT_VEYFI_PCT
        );
        _deployGaugesGrantRolesDepsoitLimitFeeSplit(
            MAINNET_YVCRVUSD_2_GAUGE,
            crvusd2,
            crvusd2MaxDeposit,
            DEFAULT_TREASURY_PCT,
            DEFAULT_COVEYFI_PCT,
            DEFAULT_USER_PCT,
            DEFAULT_VEYFI_PCT
        );

        // ================================ TESTING ===================================
        // Skip ahead to end of timelock period to execute batch
        vm.warp(block.timestamp + 2 days + 1);
        vm.startPrank(MAINNET_COVE_DEPLOYER);
        // Execute batch
        for (uint256 i = 0; i < timelockTargets.length; i++) {
            TimelockController(payable(timelock)).executeBatch(
                timelockTargets[i], timelockValues[i], timelockPayloads[i], bytes32(0), bytes32(0)
            );
        }
        vm.stopPrank();

        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true);
        }
    }

    function _deployGaugesGrantRolesDepsoitLimitFeeSplit(
        address yearnGauge,
        address newStrategy,
        uint256 maxDeposit,
        uint64 treasuryPct,
        uint64 coveYfiPct,
        uint64 userPct,
        uint64 veYfiPct
    )
        internal
        returns (address[] memory targets, uint256[] memory values, bytes[] memory payloads)
    {
        // Add gauge to YSD
        addToBatch(
            yearnStakingDelegate,
            0,
            abi.encodeCall(YearnStakingDelegate.addGaugeRewards, (yearnGauge, stakingDelegateRewards))
        );

        // Deploy the reward gauges and the forwarders via the factory
        addToBatch(coveYearnGaugeFactory, 0, abi.encodeCall(CoveYearnGaugeFactory.deployCoveGauges, (newStrategy)));

        // Fetch the gauge info
        CoveYearnGaugeFactory.GaugeInfo memory info =
            CoveYearnGaugeFactory(coveYearnGaugeFactory).getGaugeInfo(yearnGauge);
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

        // Prepare timelock batch
        targets = new address[](8);
        values = new uint256[](8);
        payloads = new bytes[](8);

        // Grant depositor role to the strategy and non-auto compounding gauge
        targets[0] = yearnStakingDelegate;
        payloads[0] = abi.encodeCall(AccessControl.grantRole, (DEPOSITOR_ROLE, info.coveYearnStrategy));
        targets[1] = yearnStakingDelegate;
        payloads[1] = abi.encodeCall(AccessControl.grantRole, (DEPOSITOR_ROLE, info.nonAutoCompoundingGauge));
        // Set deposit limit for the gauge
        targets[2] = yearnStakingDelegate;
        payloads[2] = abi.encodeCall(YearnStakingDelegate.setDepositLimit, (yearnGauge, maxDeposit));
        require(CoveToken(coveToken).allowedSender(info.autoCompoundingGauge) == false, "Already allowed sender");
        require(CoveToken(coveToken).allowedSender(info.nonAutoCompoundingGauge) == false, "Already allowed sender");
        require(
            CoveToken(coveToken).allowedSender(autoCompoundingGaugeRewardForwarder) == false, "Already allowed sender"
        );
        require(
            CoveToken(coveToken).allowedSender(nonComoundingGaugeRewardForwarder) == false, "Already allowed sender"
        );
        // Add COVE's allowed sender for the gauges and the forwarders
        targets[3] = address(coveToken);
        payloads[3] = abi.encodeCall(CoveToken.addAllowedSender, (info.autoCompoundingGauge));
        targets[4] = address(coveToken);
        payloads[4] = abi.encodeCall(CoveToken.addAllowedSender, (info.nonAutoCompoundingGauge));
        targets[5] = address(coveToken);
        payloads[5] = abi.encodeCall(CoveToken.addAllowedSender, (autoCompoundingGaugeRewardForwarder));
        targets[6] = address(coveToken);
        payloads[6] = abi.encodeCall(CoveToken.addAllowedSender, (nonComoundingGaugeRewardForwarder));
        // Set the gauge reward split for covyfi yfi gauge
        targets[7] = address(yearnStakingDelegate);
        payloads[7] = abi.encodeCall(
            YearnStakingDelegate.setGaugeRewardSplit, (yearnGauge, treasuryPct, coveYfiPct, userPct, veYfiPct)
        );

        // Queue up the timelock transaction
        addToBatch(
            timelock,
            0,
            abi.encodeCall(
                TimelockController.scheduleBatch, (targets, values, payloads, bytes32(0), bytes32(0), 2 days)
            )
        );

        timelockTargets.push(targets);
        timelockValues.push(values);
        timelockPayloads.push(payloads);
    }
}
