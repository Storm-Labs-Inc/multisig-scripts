// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { TimelockController } from
    "lib/cove-contracts-boosties/lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";
import { CoveToken } from "lib/cove-contracts-boosties/src/governance/CoveToken.sol";
import { IERC20 } from "lib/cove-contracts-boosties/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// Transfer COVE tokens to ops multisig for future LM programs.
// Allow merklDistributor address to send COVE tokens, allowing user claims.
// Roughly 30.13 million $COVE (≈ 3.01 % of the 1 B total supply) have been emitted across Season 1 and the single
// completed epoch of Season 2. Because 8 % of supply (80 M $COVE) was budgeted for liquidity-mining, about 49.87
// million $COVE remain un-allocated.
contract Script is CommunityMultisigScript, StdAssertions {
    address constant MERKL_DISTRIBUTOR = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;
    uint256 totalLMRewards = 49_869_200e18;

    function run() public {
        run(false);
    }

    function run(bool shouldSend) public override {
        super.run(shouldSend);
        address timelock = deployer.getAddress("TimelockController");
        address coveToken = deployer.getAddress("CoveToken");

        // ================================ START BATCH ===================================
        address target = MERKL_DISTRIBUTOR;
        uint256 value = 0;
        bytes memory payload = abi.encodeCall(CoveToken.addAllowedSender, (MERKL_DISTRIBUTOR));

        addToBatch(
            timelock,
            0,
            abi.encodeCall(TimelockController.schedule, (target, value, payload, bytes32(0), bytes32(0), 2 days))
        );
        addToBatch(coveToken, 0, abi.encodeCall(IERC20.transfer, (MAINNET_COVE_OPS_MULTISIG, totalLMRewards)));

        // ============================= TESTING ===================================
        // Warp to end of timelock period
        vm.warp(block.timestamp + 2 days);

        // Execute timelock
        vm.prank(MAINNET_COVE_DEPLOYER);
        TimelockController(payable(timelock)).execute(target, value, payload, bytes32(0), bytes32(0));

        // Check MERKL_DISTRIBUTOR is an allowed sender of COVE tokens
        assertTrue(CoveToken(coveToken).allowedSender(MERKL_DISTRIBUTOR));

        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true);
        }
    }
}
