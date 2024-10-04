// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CoveToken } from "cove-contracts-boosties/src/governance/CoveToken.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";

contract Script is CommunityMultisigScript, StdAssertions {
    function run(bool shouldSend) public override {
        super.run(shouldSend);
        uint256 totalRewards = 3_500_000 ether;
        address coveToken = deployer.getAddress("CoveToken");

        uint256 communityBalanceBefore = CoveToken(coveToken).balanceOf(MAINNET_COVE_COMMUNITY_MULTISIG);
        uint256 opsBalanceBefore = CoveToken(coveToken).balanceOf(MAINNET_COVE_OPS_MULTISIG);

        // ================================ START BATCH ===================================
        // Add to batch
        addToBatch(coveToken, 0, abi.encodeCall(IERC20.transfer, (MAINNET_COVE_OPS_MULTISIG, totalRewards)));

        // ================================ TESTING ===================================
        uint256 communityBalanceAfter = CoveToken(coveToken).balanceOf(MAINNET_COVE_COMMUNITY_MULTISIG);
        uint256 opsBalanceAfter = CoveToken(coveToken).balanceOf(MAINNET_COVE_OPS_MULTISIG);
        assertEq(communityBalanceBefore - communityBalanceAfter, totalRewards, "should have sent cove tokens");
        assertEq(opsBalanceAfter - opsBalanceBefore, totalRewards, "should have sent cove tokens to ops");
        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true);
        }
    }
}
