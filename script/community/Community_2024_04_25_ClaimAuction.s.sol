// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CoveToken } from "cove-contracts-boosties/src/governance/CoveToken.sol";
import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { YearnStakingDelegate } from "cove-contracts-boosties/src/YearnStakingDelegate.sol";

interface Auction {
    function claimAuctioneerTokens() external;
}

contract Script is CommunityMultisigScript {
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
        // https://etherscan.io/address/0x2f3715F710076Cfdb5AA872Bc8a4b965a07c3A08
        address auction = 0x2f3715F710076Cfdb5AA872Bc8a4b965a07c3A08;

        uint256 coveBalanceBefore = CoveToken(coveToken).balanceOf(MAINNET_COVE_COMMUNITY_MULTISIG);
        uint256 ethBalanceBefore = MAINNET_COVE_COMMUNITY_MULTISIG.balance;

        // ================================ START BATCH ===================================
        // Add to batch
        addToBatch(auction, 0, abi.encodeCall(Auction.claimAuctioneerTokens, ()));

        // ================================ TESTING ===================================
        require(
            CoveToken(coveToken).balanceOf(MAINNET_COVE_COMMUNITY_MULTISIG) > coveBalanceBefore,
            "should have claimed cove tokens"
        );
        require(MAINNET_COVE_COMMUNITY_MULTISIG.balance > ethBalanceBefore, "should have claimed eth");

        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true);
        }
    }
}
