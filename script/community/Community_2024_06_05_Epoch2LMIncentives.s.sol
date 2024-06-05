// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CoveToken } from "cove-contracts-boosties/src/governance/CoveToken.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";

contract Script is CommunityMultisigScript, StdAssertions {
    function run(bool shouldSend) public override {
        super.run(shouldSend);
        // amounts from: https://docs.cove.finance/ecosystem/token/info#epoch-2
        uint256 coveYFIRewardAmount = 2_800_000 ether;
        uint256 coveBoostiesV2LPTokenRewardAmount = 600_000 ether;
        uint256 coveBoostiesV3LPTokenRewardAmount = 600_000 ether;
        uint256 totalRewards =
            coveYFIRewardAmount + coveBoostiesV2LPTokenRewardAmount + coveBoostiesV3LPTokenRewardAmount;
        assertEq(totalRewards, 4_000_000 ether, "total rewards should be 4M");

        uint256 foundationAmount = 150_000_000 ether;
        address foundationMultisig = 0x790Aa9AD0bBce251A6d72E71Bc27DeE42F626087;
        address coveToken = deployer.getAddress("CoveToken");

        uint256 communityBalanceBefore = CoveToken(coveToken).balanceOf(MAINNET_COVE_COMMUNITY_MULTISIG);
        uint256 opsBalanceBefore = CoveToken(coveToken).balanceOf(MAINNET_COVE_OPS_MULTISIG);

        // ================================ START BATCH ===================================
        // Add to batch
        addToBatch(coveToken, 0, abi.encodeCall(IERC20.transfer, (MAINNET_COVE_OPS_MULTISIG, totalRewards)));
        // Send 150M COVE to the foundation multisig
        addToBatch(coveToken, 0, abi.encodeCall(IERC20.transfer, (foundationMultisig, foundationAmount)));

        // ================================ TESTING ===================================
        uint256 communityBalanceAfter = CoveToken(coveToken).balanceOf(MAINNET_COVE_COMMUNITY_MULTISIG);
        uint256 opsBalanceAfter = CoveToken(coveToken).balanceOf(MAINNET_COVE_OPS_MULTISIG);
        assertEq(
            communityBalanceBefore - communityBalanceAfter,
            totalRewards + foundationAmount,
            "should have sent cove tokens"
        );
        assertEq(opsBalanceAfter - opsBalanceBefore, totalRewards, "should have sent cove tokens to ops");
        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true);
        }
    }
}
