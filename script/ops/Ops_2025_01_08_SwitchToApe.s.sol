// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { OpsMultisigScript } from "./OpsMultisigScript.s.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { TokenizedStrategy } from "lib/cove-contracts-boosties/lib/tokenized-strategy/src/TokenizedStrategy.sol";
import { IAccessControl } from
    "lib/cove-contracts-boosties/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { CoveYearnGaugeFactory } from "lib/cove-contracts-boosties/src/registries/CoveYearnGaugeFactory.sol";

contract Script is OpsMultisigScript, StdAssertions {
    address constant NEW_KEEPER = 0xd31336617fC8B5Ee3b162d88e75B9236a9be3d6D;

    function run(bool shouldSend) public override {
        super.run(shouldSend);

        CoveYearnGaugeFactory factory = CoveYearnGaugeFactory(deployer.getAddress("CoveYearnGaugeFactory"));
        CoveYearnGaugeFactory.GaugeInfo[] memory info = factory.getAllGaugeInfo(100, 0);

        // ================================ START BATCH ===================================

        // Update keeper for all strategies
        for (uint256 i = 0; i < info.length; i++) {
            addToBatch(info[i].coveYearnStrategy, abi.encodeCall(TokenizedStrategy.setKeeper, (NEW_KEEPER)));
        }

        // ================================ TESTING ===================================
        // Testing will be done in the simulation when executing the batch

        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true);
        }
    }
}
