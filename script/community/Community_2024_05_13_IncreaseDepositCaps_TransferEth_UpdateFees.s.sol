// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { YearnStakingDelegate } from "cove-contracts-boosties/src/YearnStakingDelegate.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

contract Script is CommunityMultisigScript, StdAssertions {
    // $1,006,863,078,121.5 per share. (1e18 yvUSDC-1 gauge is roughly equivalent to 1e12 USDC)
    uint256 public constant MAINNET_YVUSDC_GAUGE_MAX_DEPOSIT = 198_636_740_531;
    // $1.0089554 per share
    uint256 public constant MAINNET_YVDAI_GAUGE_MAX_DEPOSIT = 198_224_817_469_632_453_525_695;

    function run(bool shouldSend) public override {
        super.run(shouldSend);
        address ysd = deployer.getAddress("YearnStakingDelegate");
        address timelock = deployer.getAddress("TimelockController");

        address[] memory targets = new address[](10);
        uint256[] memory values = new uint256[](10);
        bytes[] memory payloads = new bytes[](10);

        uint256 ethBalance = address(MAINNET_COVE_COMMUNITY_MULTISIG).balance;

        // ================================ START BATCH ===================================
        // Increase deposit caps
        targets[0] = ysd;
        payloads[0] = abi.encodeCall(
            YearnStakingDelegate.setDepositLimit, (MAINNET_YVUSDC_GAUGE, MAINNET_YVUSDC_GAUGE_MAX_DEPOSIT)
        );
        targets[1] = ysd;
        payloads[1] =
            abi.encodeCall(YearnStakingDelegate.setDepositLimit, (MAINNET_YVDAI_GAUGE, MAINNET_YVDAI_GAUGE_MAX_DEPOSIT));

        // Update fees
        //     function setGaugeRewardSplit(
        //     address gauge,
        //     uint64 treasuryPct,
        //     uint64 coveYfiPct,
        //     uint64 userPct,
        //     uint64 veYfiPct
        // )
        targets[2] = ysd;
        payloads[2] = abi.encodeCall(
            YearnStakingDelegate.setGaugeRewardSplit, (MAINNET_ETH_YFI_GAUGE, 15.62e16, 5e16, 50.37e16, 29.01e16)
        );
        targets[3] = ysd;
        payloads[3] = abi.encodeCall(
            YearnStakingDelegate.setGaugeRewardSplit, (MAINNET_DYFI_ETH_GAUGE, 6.02e16, 5e16, 77.79e16, 11.19e16)
        );
        targets[4] = ysd;
        payloads[4] = abi.encodeCall(
            YearnStakingDelegate.setGaugeRewardSplit, (MAINNET_WETH_YETH_GAUGE, 3.67e16, 5e16, 84.5e16, 6.83e16)
        );
        targets[5] = ysd;
        payloads[5] =
            abi.encodeCall(YearnStakingDelegate.setGaugeRewardSplit, (MAINNET_CRV_YCRV_GAUGE, 0, 5e16, 90e16, 5e16));
        targets[6] = ysd;
        payloads[6] = abi.encodeCall(
            YearnStakingDelegate.setGaugeRewardSplit, (MAINNET_PRISMA_YPRISMA_GAUGE, 0, 5e16, 90e16, 5e16)
        );
        targets[7] = ysd;
        payloads[7] =
            abi.encodeCall(YearnStakingDelegate.setGaugeRewardSplit, (MAINNET_YVUSDC_GAUGE, 0, 5e16, 90e16, 5e16));
        targets[8] = ysd;
        payloads[8] =
            abi.encodeCall(YearnStakingDelegate.setGaugeRewardSplit, (MAINNET_YVDAI_GAUGE, 0, 5e16, 90e16, 5e16));
        targets[9] = ysd;
        payloads[9] =
            abi.encodeCall(YearnStakingDelegate.setGaugeRewardSplit, (MAINNET_YVWETH_GAUGE, 0, 5e16, 90e16, 5e16));

        // Add to batch
        addToBatch(
            timelock,
            0,
            abi.encodeCall(
                TimelockController.scheduleBatch, (targets, values, payloads, bytes32(0), bytes32(0), 2 days)
            )
        );

        // Transfer ETH from the auction to ops multisig for coveYFI minting
        addToBatch(MAINNET_COVE_OPS_MULTISIG, address(MAINNET_COVE_COMMUNITY_MULTISIG).balance, new bytes(0));

        // ================================ TESTING ===================================

        // Warp to end of timelock period
        vm.warp(block.timestamp + 2 days);

        // Execute timelock's scheduled batch
        vm.prank(MAINNET_COVE_DEPLOYER);
        TimelockController(payable(timelock)).executeBatch(targets, values, payloads, bytes32(0), bytes32(0));

        assertEq(
            YearnStakingDelegate(ysd).depositLimit(MAINNET_YVUSDC_GAUGE),
            MAINNET_YVUSDC_GAUGE_MAX_DEPOSIT,
            "should have set deposit limit for yvUSDC"
        );
        assertEq(
            YearnStakingDelegate(ysd).depositLimit(MAINNET_YVDAI_GAUGE),
            MAINNET_YVDAI_GAUGE_MAX_DEPOSIT,
            "should have set deposit limit for yvDAI"
        );

        assertEq(address(MAINNET_COVE_OPS_MULTISIG).balance, ethBalance, "should have transferred all eth to ops");
        assertEq(address(MAINNET_COVE_COMMUNITY_MULTISIG).balance, 0, "should have transferred all eth to ops");

        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true);
        }
    }
}
