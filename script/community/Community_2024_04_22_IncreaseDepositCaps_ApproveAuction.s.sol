// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { CoveToken } from "cove-contracts-boosties/src/governance/CoveToken.sol";
import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";
import { console2 as console } from "forge-std/console2.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { YearnStakingDelegate } from "cove-contracts-boosties/src/YearnStakingDelegate.sol";

struct BatchAuctionUncappedConfig {
    IERC20 projectToken; // coveToken
    IERC20 quoteToken; // weth 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2
    uint256 projectTokenAmount; // 95_000_000 ether
    uint256 floorQuoteAmount; // 903.66603 ether
    uint256 startTime; // 1713758400
    uint256 endTime; // 1714017600
}

interface BazaarBatchAuctionFactory {
    function createAuction(BatchAuctionUncappedConfig memory cfg) external returns (BazaarAuction);
}

interface BazaarAuction {
    function subscribe(address subscriber, uint256 amount) external payable;
    function claimProjectToken() external;
    function claimAuctioneerTokens() external;
}

contract Script is CommunityMultisigScript {
    uint256 private constant _START_TIME = 1_713_801_600; // April 22nd, 2024 16:00 UTC
    uint256 private constant _END_TIME = 1_714_060_800; // April 25th, 2024 16:00 UTC

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

    function run(bool shouldSend) public override {
        super.run(shouldSend);
        address coveToken = deployer.getAddress("CoveToken");
        address timelock = deployer.getAddress("TimelockController");
        address ysd = deployer.getAddress("YearnStakingDelegate");
        // https://etherscan.io/address/0x2f3715F710076Cfdb5AA872Bc8a4b965a07c3A08
        address auction = 0x2f3715F710076Cfdb5AA872Bc8a4b965a07c3A08;

        // ================================ START BATCH ===================================

        address[] memory targets = new address[](9);
        uint256[] memory values = new uint256[](9);
        bytes[] memory payloads = new bytes[](9);

        // Approve auction contract to send COVE so participants can claim COVE after the auction ends
        targets[0] = coveToken;
        payloads[0] = abi.encodeCall(CoveToken.addAllowedSender, (auction));

        // Increase deposit caps
        targets[1] = ysd;
        payloads[1] = abi.encodeCall(
            YearnStakingDelegate.setDepositLimit, (MAINNET_WETH_YETH_GAUGE, MAINNET_WETH_YETH_POOL_GAUGE_MAX_DEPOSIT)
        );
        targets[2] = ysd;
        payloads[2] = abi.encodeCall(
            YearnStakingDelegate.setDepositLimit, (MAINNET_ETH_YFI_GAUGE, MAINNET_ETH_YFI_GAUGE_MAX_DEPOSIT)
        );
        targets[3] = ysd;
        payloads[3] = abi.encodeCall(
            YearnStakingDelegate.setDepositLimit, (MAINNET_DYFI_ETH_GAUGE, MAINNET_DYFI_ETH_GAUGE_MAX_DEPOSIT)
        );
        targets[4] = ysd;
        payloads[4] = abi.encodeCall(
            YearnStakingDelegate.setDepositLimit, (MAINNET_CRV_YCRV_GAUGE, MAINNET_CRV_YCRV_POOL_GAUGE_MAX_DEPOSIT)
        );
        targets[5] = ysd;
        payloads[5] = abi.encodeCall(
            YearnStakingDelegate.setDepositLimit,
            (MAINNET_PRISMA_YPRISMA_GAUGE, MAINNET_PRISMA_YPRISMA_POOL_GAUGE_MAX_DEPOSIT)
        );
        targets[6] = ysd;
        payloads[6] = abi.encodeCall(
            YearnStakingDelegate.setDepositLimit, (MAINNET_YVUSDC_GAUGE, MAINNET_YVUSDC_GAUGE_MAX_DEPOSIT)
        );
        targets[7] = ysd;
        payloads[7] =
            abi.encodeCall(YearnStakingDelegate.setDepositLimit, (MAINNET_YVDAI_GAUGE, MAINNET_YVDAI_GAUGE_MAX_DEPOSIT));
        targets[8] = ysd;
        payloads[8] = abi.encodeCall(
            YearnStakingDelegate.setDepositLimit, (MAINNET_YVWETH_GAUGE, MAINNET_YVWETH_GAUGE_MAX_DEPOSIT)
        );

        // Add to batch
        addToBatch(
            timelock,
            0,
            abi.encodeCall(
                TimelockController.scheduleBatch, (targets, values, payloads, bytes32(0), bytes32(0), 2 days)
            )
        );

        // ================================ TESTING ===================================

        // Warp to end of timelock period
        vm.warp(block.timestamp + 2 days);

        // Check for status before executing batch
        // Check auction contract is NOT an allowed sender before
        require(!CoveToken(coveToken).allowedSender(auction), "auction contract is already an allowed sender");
        // Check that deposit cap is set to different value before
        require(
            YearnStakingDelegate(ysd).depositLimit(MAINNET_WETH_YETH_GAUGE) < MAINNET_WETH_YETH_POOL_GAUGE_MAX_DEPOSIT,
            "deposit cap is already set"
        );
        require(
            YearnStakingDelegate(ysd).depositLimit(MAINNET_ETH_YFI_GAUGE) < MAINNET_ETH_YFI_GAUGE_MAX_DEPOSIT,
            "deposit cap is already set"
        );
        require(
            YearnStakingDelegate(ysd).depositLimit(MAINNET_DYFI_ETH_GAUGE) < MAINNET_DYFI_ETH_GAUGE_MAX_DEPOSIT,
            "deposit cap is already set"
        );
        require(
            YearnStakingDelegate(ysd).depositLimit(MAINNET_CRV_YCRV_GAUGE) < MAINNET_CRV_YCRV_POOL_GAUGE_MAX_DEPOSIT,
            "deposit cap is already set"
        );
        require(
            YearnStakingDelegate(ysd).depositLimit(MAINNET_PRISMA_YPRISMA_GAUGE)
                < MAINNET_PRISMA_YPRISMA_POOL_GAUGE_MAX_DEPOSIT,
            "deposit cap is already set"
        );
        // yvUSDC-1 gauge deposit cap was higher before due to incorrect decimal conversion
        require(
            YearnStakingDelegate(ysd).depositLimit(MAINNET_YVUSDC_GAUGE) != MAINNET_YVUSDC_GAUGE_MAX_DEPOSIT,
            "deposit cap is already set"
        );
        require(
            YearnStakingDelegate(ysd).depositLimit(MAINNET_YVDAI_GAUGE) < MAINNET_YVDAI_GAUGE_MAX_DEPOSIT,
            "deposit cap is already set"
        );
        require(
            YearnStakingDelegate(ysd).depositLimit(MAINNET_YVWETH_GAUGE) < MAINNET_YVWETH_GAUGE_MAX_DEPOSIT,
            "deposit cap is already set"
        );

        // Execute timelock's scheduled batch
        vm.prank(MAINNET_COVE_DEPLOYER);
        TimelockController(payable(timelock)).executeBatch(targets, values, payloads, bytes32(0), bytes32(0));

        // Check for status after executing batch
        // Check auction contract is an allowed sender after
        require(CoveToken(coveToken).allowedSender(auction), "failed to allow auction contract");
        // Check that deposit cap is set to expected values after
        require(
            YearnStakingDelegate(ysd).depositLimit(MAINNET_WETH_YETH_GAUGE) == MAINNET_WETH_YETH_POOL_GAUGE_MAX_DEPOSIT,
            "failed to set deposit cap"
        );
        require(
            YearnStakingDelegate(ysd).depositLimit(MAINNET_ETH_YFI_GAUGE) == MAINNET_ETH_YFI_GAUGE_MAX_DEPOSIT,
            "failed to set deposit cap"
        );
        require(
            YearnStakingDelegate(ysd).depositLimit(MAINNET_DYFI_ETH_GAUGE) == MAINNET_DYFI_ETH_GAUGE_MAX_DEPOSIT,
            "failed to set deposit cap"
        );
        require(
            YearnStakingDelegate(ysd).depositLimit(MAINNET_CRV_YCRV_GAUGE) == MAINNET_CRV_YCRV_POOL_GAUGE_MAX_DEPOSIT,
            "failed to set deposit cap"
        );
        require(
            YearnStakingDelegate(ysd).depositLimit(MAINNET_PRISMA_YPRISMA_GAUGE)
                == MAINNET_PRISMA_YPRISMA_POOL_GAUGE_MAX_DEPOSIT,
            "failed to set deposit cap"
        );
        require(
            YearnStakingDelegate(ysd).depositLimit(MAINNET_YVUSDC_GAUGE) == MAINNET_YVUSDC_GAUGE_MAX_DEPOSIT,
            "failed to set deposit cap"
        );
        require(
            YearnStakingDelegate(ysd).depositLimit(MAINNET_YVDAI_GAUGE) == MAINNET_YVDAI_GAUGE_MAX_DEPOSIT,
            "failed to set deposit cap"
        );
        require(
            YearnStakingDelegate(ysd).depositLimit(MAINNET_YVWETH_GAUGE) == MAINNET_YVWETH_GAUGE_MAX_DEPOSIT,
            "failed to set deposit cap"
        );

        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true);
        }
    }
}
