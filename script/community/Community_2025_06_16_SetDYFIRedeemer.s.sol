// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { CoveYearnGaugeFactory } from "cove-contracts-boosties/src/registries/CoveYearnGaugeFactory.sol";
import { YearnGaugeStrategy } from "cove-contracts-boosties/src/strategies/YearnGaugeStrategy.sol";
import { ITokenizedStrategy } from
    "cove-contracts-boosties/lib/tokenized-strategy/src/interfaces/ITokenizedStrategy.sol";

interface IDYFIRedeemer {
    function kill() external;
}

interface ISwapAndLock {
    function setDYfiRedeemer(address) external;
    function kill() external;
}

interface IMasterRegistry {
    function addRegistry(bytes32, address) external;
}

contract Script is CommunityMultisigScript, StdAssertions {
    function run() public {
        run(false);
    }

    function run(bool shouldSend) public override {
        super.run(shouldSend);
        address swapAndLock = deployer.getAddress("SwapAndLock");
        address dyfiRedeemerV2 = 0x17072491906E25323175454044642054d97767Fd;
        address dyfiRedeemer = deployer.getAddress("DYFIRedeemer");

        // ================================ START BATCH ===================================
        // Add to batch - update SwapAndLock contract
        addToBatch(swapAndLock, 0, abi.encodeCall(ISwapAndLock.setDYfiRedeemer, dyfiRedeemerV2));

        // Kill old redeemer
        addToBatch(dyfiRedeemer, 0, abi.encodeCall(IDYFIRedeemer.kill, ()));

        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true);
        }
    }
}
