// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CoveToken } from "cove-contracts-boosties/src/governance/CoveToken.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";

interface ReverseRegistrar {
    function setName(string calldata name) external;
}

contract Script is CommunityMultisigScript, StdAssertions {
    function run(bool shouldSend) public override {
        super.run(shouldSend);
        address reverseRegistrar = 0xa58E81fe9b61B5c3fE2AFD33CF304c454AbFc7Cb;
        // ================================ START BATCH ===================================
        // Add to batch
        addToBatch(reverseRegistrar, 0, abi.encodeCall(ReverseRegistrar.setName, ("community.covefi.eth")));
        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true);
        }
    }
}
