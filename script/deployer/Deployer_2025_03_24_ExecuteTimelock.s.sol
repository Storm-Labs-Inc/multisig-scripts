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
    // Uses prices from 2025-03-24
    // $1.00 per share
    uint256 public constant MAINNET_USDS_MAX_DEPOSIT = 100_000e18;

    function run() public override {
        super.run();
        vm.startBroadcast(MAINNET_COVE_DEPLOYER);

        address coveToken = deployer.getAddress("CoveToken");
        address timelock = deployer.getAddress("TimelockController");
        address ysd = deployer.getAddress("YearnStakingDelegate");
        address coveYearnGaugeFactory = deployer.getAddress("CoveYearnGaugeFactory");

        // ================================ START BATCH ===================================
        CoveYearnGaugeFactory.GaugeInfo memory info =
            CoveYearnGaugeFactory(coveYearnGaugeFactory).getGaugeInfo(MAINNET_YVUSDS_1_GAUGE);
        address autoCompoundingGaugeRewardForwarder =
            ERC20RewardsGauge(info.autoCompoundingGauge).getRewardData(address(coveToken)).distributor;
        address nonComoundingGaugeRewardForwarder =
            ERC20RewardsGauge(info.nonAutoCompoundingGauge).getRewardData(address(coveToken)).distributor;

        address[] memory targets = new address[](8);
        uint256[] memory values = new uint256[](8);
        bytes[] memory payloads = new bytes[](8);

        // Grant depositor role to the strategy and non-auto compounding gauge
        targets[0] = ysd;
        payloads[0] = abi.encodeCall(AccessControl.grantRole, (DEPOSITOR_ROLE, info.coveYearnStrategy));
        targets[1] = ysd;
        payloads[1] = abi.encodeCall(AccessControl.grantRole, (DEPOSITOR_ROLE, info.nonAutoCompoundingGauge));
        // Set deposit limit for the gauge
        targets[2] = ysd;
        payloads[2] =
            abi.encodeCall(YearnStakingDelegate.setDepositLimit, (MAINNET_YVUSDS_1_GAUGE, MAINNET_USDS_MAX_DEPOSIT));
        // Add COVE's allowed sender for the gauges and the forwarders
        targets[3] = coveToken;
        payloads[3] = abi.encodeCall(CoveToken.addAllowedSender, (info.autoCompoundingGauge));
        targets[4] = coveToken;
        payloads[4] = abi.encodeCall(CoveToken.addAllowedSender, (info.nonAutoCompoundingGauge));
        targets[5] = coveToken;
        payloads[5] = abi.encodeCall(CoveToken.addAllowedSender, (autoCompoundingGaugeRewardForwarder));
        targets[6] = coveToken;
        payloads[6] = abi.encodeCall(CoveToken.addAllowedSender, (nonComoundingGaugeRewardForwarder));
        // Set the gauge reward split for yvUSDS-1 gauge
        targets[7] = ysd;
        payloads[7] = abi.encodeCall(
            YearnStakingDelegate.setGaugeRewardSplit, (MAINNET_YVUSDS_1_GAUGE, 0, 0.05e18, 0.9e18, 0.05e18)
        );
        TimelockController(payable(timelock)).executeBatch(targets, values, payloads, bytes32(0), bytes32(0));

        address[] memory yearnGauges = new address[](1);
        yearnGauges[0] = MAINNET_YVUSDS_1_GAUGE;
        _approveTokensInRouter(yearnGauges);
    }

    function _approveTokensInRouter(address[] memory yearnGauges) internal {
        CoveYearnGaugeFactory factory = CoveYearnGaugeFactory(deployer.getAddress("CoveYearnGaugeFactory"));
        CoveYearnGaugeFactory.GaugeInfo[] memory info = new CoveYearnGaugeFactory.GaugeInfo[](yearnGauges.length);
        uint256 numOfTokensToApprove = 5;

        // Get the gauge info for each yearn gauge
        for (uint256 i = 0; i < yearnGauges.length; i++) {
            info[i] = factory.getGaugeInfo(yearnGauges[i]);
        }
        Yearn4626RouterExt router = Yearn4626RouterExt(deployer.getAddress("Yearn4626RouterExt2"));
        bytes[] memory data = new bytes[](info.length * numOfTokensToApprove);

        // Approve the tokens for the yearn vault, yearn gauge, cove strategy, auto compounding gauge and non auto
        // compounding gauge
        for (uint256 i = 0; i < data.length;) {
            CoveYearnGaugeFactory.GaugeInfo memory gaugeInfo = info[i / numOfTokensToApprove];
            data[i++] = abi.encodeWithSelector(
                PeripheryPayments.approve.selector, gaugeInfo.yearnVaultAsset, gaugeInfo.yearnVault, _MAX_UINT256
            );
            data[i++] = abi.encodeWithSelector(
                PeripheryPayments.approve.selector, gaugeInfo.yearnVault, gaugeInfo.yearnGauge, _MAX_UINT256
            );
            data[i++] = abi.encodeWithSelector(
                PeripheryPayments.approve.selector, gaugeInfo.yearnGauge, gaugeInfo.coveYearnStrategy, _MAX_UINT256
            );
            data[i++] = abi.encodeWithSelector(
                PeripheryPayments.approve.selector,
                gaugeInfo.coveYearnStrategy,
                gaugeInfo.autoCompoundingGauge,
                _MAX_UINT256
            );
            data[i++] = abi.encodeWithSelector(
                PeripheryPayments.approve.selector,
                gaugeInfo.yearnGauge,
                gaugeInfo.nonAutoCompoundingGauge,
                _MAX_UINT256
            );
        }
        // TODO run this after the gauges are deployed.
        router.multicall(data);
    }
}
