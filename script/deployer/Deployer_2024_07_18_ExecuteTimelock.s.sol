// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CoveToken } from "cove-contracts-boosties/src/governance/CoveToken.sol";
import { DeployerScript } from "./DeployerScript.s.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { YearnStakingDelegate } from "cove-contracts-boosties/src/YearnStakingDelegate.sol";
import { CoveYearnGaugeFactory } from "cove-contracts-boosties/src/registries/CoveYearnGaugeFactory.sol";
import { ERC20RewardsGauge } from "cove-contracts-boosties/src/rewards/ERC20RewardsGauge.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract Script is DeployerScript {
    // Uses prices from 2024-04-22
    // $3246.07 per share
    uint256 public constant MAINNET_WETH_YETH_POOL_GAUGE_MAX_DEPOSIT = 30_806_471_570_663_775_570;
    // $10505.09 per share
    uint256 public constant MAINNET_ETH_YFI_GAUGE_MAX_DEPOSIT = 9_519_192_070_123_790_491;
    // $8699.91 per share
    uint256 public constant MAINNET_DYFI_ETH_GAUGE_MAX_DEPOSIT = 11_494_359_443_151_212_300;
    // $0.47 per share
    uint256 public constant MAINNET_CRV_YCRV_POOL_GAUGE_MAX_DEPOSIT = 212_255_726_614_570_499_304_899;
    // $0.29 per share
    uint256 public constant MAINNET_PRISMA_YPRISMA_POOL_GAUGE_MAX_DEPOSIT = 343_179_042_193_360_546_727_139;
    // $1,003,436,982,790 per share. (1e18 yvUSDC-1 gauge is equivalent to 1e12 USDC)
    uint256 public constant MAINNET_YVUSDC_GAUGE_MAX_DEPOSIT = 99_657_478_959;
    // $1.006 per share
    uint256 public constant MAINNET_YVDAI_GAUGE_MAX_DEPOSIT = 99_361_801_903_599_043_906_750;
    // $3179.23 per share
    uint256 public constant MAINNET_YVWETH_GAUGE_MAX_DEPOSIT = 31_454_127_974_689_390_752;

    function run() public override {
        super.run();
        vm.startBroadcast(MAINNET_COVE_DEPLOYER);

        address coveToken = deployer.getAddress("CoveToken");
        address timelock = deployer.getAddress("TimelockController");
        address ysd = deployer.getAddress("YearnStakingDelegate");
        address coveYearnGaugeFactory = deployer.getAddress("CoveYearnGaugeFactory");
        // 100k USD deposit limit with 4529.94 USD per COVEYFI/YFI LP token
        uint256 maxDeposit = uint256(100_000e18 * 1e18) / 4529.94e18;

        // ================================ START BATCH ===================================
        CoveYearnGaugeFactory.GaugeInfo memory info =
            CoveYearnGaugeFactory(coveYearnGaugeFactory).getGaugeInfo(MAINNET_COVEYFI_YFI_GAUGE);
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
        payloads[2] = abi.encodeCall(YearnStakingDelegate.setDepositLimit, (MAINNET_COVEYFI_YFI_GAUGE, maxDeposit));
        // Add COVE's allowed sender for the gauges and the forwarders
        targets[3] = coveToken;
        payloads[3] = abi.encodeCall(CoveToken.addAllowedSender, (info.autoCompoundingGauge));
        targets[4] = coveToken;
        payloads[4] = abi.encodeCall(CoveToken.addAllowedSender, (info.nonAutoCompoundingGauge));
        targets[5] = coveToken;
        payloads[5] = abi.encodeCall(CoveToken.addAllowedSender, (autoCompoundingGaugeRewardForwarder));
        targets[6] = coveToken;
        payloads[6] = abi.encodeCall(CoveToken.addAllowedSender, (nonComoundingGaugeRewardForwarder));
        // Set the gauge reward split for covyfi yfi gauge
        targets[7] = ysd;
        payloads[7] = abi.encodeCall(
            YearnStakingDelegate.setGaugeRewardSplit, (MAINNET_COVEYFI_YFI_GAUGE, 0.05e18, 0, 0.9e18, 0.05e18)
        );

        TimelockController(payable(timelock)).executeBatch(targets, values, payloads, bytes32(0), bytes32(0));
    }
}
