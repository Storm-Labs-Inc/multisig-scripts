// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CoveToken } from "cove-contracts-boosties/src/governance/CoveToken.sol";
import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";

interface Auction {
    function claimAuctioneerTokens() external;
}

contract Script is CommunityMultisigScript, StdAssertions {
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
        uint256 coveBalanceAfter = CoveToken(coveToken).balanceOf(MAINNET_COVE_COMMUNITY_MULTISIG);
        uint256 ethBalanceAfter = MAINNET_COVE_COMMUNITY_MULTISIG.balance;
        assertEq(
            coveBalanceAfter - coveBalanceBefore, 86_591_731_398_525_314_835_022_625, "should have claimed cove tokens"
        );
        assertEq(ethBalanceAfter - ethBalanceBefore, 79_181_937_254_795_769_260, "should have claimed eth");

        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true);
        }
    }
}
