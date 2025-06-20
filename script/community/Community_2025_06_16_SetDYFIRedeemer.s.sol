// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";

interface ISwapAndLock {
    function setDYfiRedeemer(address) external;
}

interface IMasterRegistry {
    function addRegistry(bytes32, address) external;
}

contract Script is CommunityMultisigScript, StdAssertions {
    function run(bool shouldSend) public override {
        super.run(shouldSend);
        address swapAndLock = 0x9dadf9487737DE29ac685d231bB94348a2635CBb;
        address dyfiRedeemerV2 = 0x0000000000000000000000000000000000000000;
        address masterRegistry = 0x91cf20C03bEC656BC008fB2a2177bC3caA34f772;
        // ================================ START BATCH ===================================
        // Add to batch
        addToBatch(swapAndLock, 0, abi.encodeCall(ISwapAndLock.setDYfiRedeemer, dyfiRedeemerV2));
        // Add new contract to master registry
        // TODO: should be a new entry or update the existing one?
        addToBatch(
            masterRegistry,
            0,
            abi.encodeCall(IMasterRegistry.addRegistry, (keccak256("DYFIRedeemerv2"), dyfiRedeemerV2))
        );
        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true);
        }
    }
}
