// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { OpsMultisigScript } from "./OpsMultisigScript.s.sol";
import { TokenizedStrategy } from "tokenized-strategy/TokenizedStrategy.sol";
import { YearnGaugeStrategy } from "cove-contracts-boosties/src/strategies/YearnGaugeStrategy.sol";

contract Script is OpsMultisigScript {
    function run(bool shouldSend) public override {
        super.run(shouldSend);
        address dai2 = deployer.getAddress("YearnGaugeStrategy-yGauge DAI-2 yVault");
        address weth2 = deployer.getAddress("YearnGaugeStrategy-yGauge WETH-2 yVault");
        address crvusd2 = deployer.getAddress("YearnGaugeStrategy-yGauge crvUSD-2 yVault");

        // Add to batch
        addToBatch(dai2, 0, abi.encodeWithSelector(TokenizedStrategy.acceptManagement.selector));
        addToBatch(weth2, 0, abi.encodeWithSelector(TokenizedStrategy.acceptManagement.selector));
        addToBatch(crvusd2, 0, abi.encodeWithSelector(TokenizedStrategy.acceptManagement.selector));

        // Execute batch
        if (shouldSend) executeBatch(true);
    }
}
