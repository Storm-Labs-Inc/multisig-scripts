// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { OpsMultisigScript } from "./OpsMultisigScript.s.sol";
import { TokenizedStrategy } from "tokenized-strategy/src/TokenizedStrategy.sol";
import { YearnGaugeStrategy } from "cove-contracts-boosties/src/strategies/YearnGaugeStrategy.sol";

contract Script is OpsMultisigScript {
    function run(bool shouldSend) public override {
        super.run(shouldSend);
        address newStrategy = deployer.getAddress("YearnGaugeStrategy-yGauge Curve COVEYFI Factory yVault");
        address dYfiRedeemer = deployer.getAddress("DYFIRedeemer");

        // Add to batch
        addToBatch(newStrategy, 0, abi.encodeWithSelector(TokenizedStrategy.acceptManagement.selector));
        addToBatch(newStrategy, 0, abi.encodeCall(YearnGaugeStrategy.setDYfiRedeemer, (dYfiRedeemer)));

        // Execute batch
        if (shouldSend) executeBatch(true);
    }
}
