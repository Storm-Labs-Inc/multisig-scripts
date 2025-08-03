// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { CoveYearnGaugeFactory } from "cove-contracts-boosties/src/registries/CoveYearnGaugeFactory.sol";
import { YearnGaugeStrategy } from "cove-contracts-boosties/src/strategies/YearnGaugeStrategy.sol";
import { ITokenizedStrategy } from
    "cove-contracts-boosties/lib/tokenized-strategy/src/interfaces/ITokenizedStrategy.sol";

import { console } from "forge-std/console.sol";

interface IEulerRouter {
    function govSetConfig(address base, address quote, address oracle) external;
    function getConfiguredOracle(address base, address quote) external view returns (address);
}

// Replace the registered sfrxUSD oracle with the new one at 0xC3E2e5154B1D337384f5B32713a6810822A64959
contract Script is CommunityMultisigScript, StdAssertions {
    function run() public {
        run(false);
    }

    function run(bool shouldSend) public override {
        super.run(shouldSend);

        // Production Euler Router
        address eulerRouter = 0xECC9556F546950619e84C5C70FDF19D89dB8Aad7;

        address sfrxUSD = 0xcf62F905562626CfcDD2261162a51fd02Fc9c5b6;
        address USD = address(840); // USD ISO 4217 currency code
        address newOracle = 0xC3E2e5154B1D337384f5B32713a6810822A64959;

        // ================================ START BATCH ===================================
        address previousOracle = IEulerRouter(eulerRouter).getConfiguredOracle(sfrxUSD, USD);
        console.log("Previous oracle", previousOracle);

        // Add to batch - update SwapAndLock contract
        addToBatch(eulerRouter, 0, abi.encodeCall(IEulerRouter.govSetConfig, (sfrxUSD, USD, newOracle)));

        // ================================ TEST ===================================
        address replacedOracle = IEulerRouter(eulerRouter).getConfiguredOracle(sfrxUSD, USD);
        assertEq(replacedOracle, newOracle);
        console.log("New oracle", newOracle);

        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true);
        }
    }
}
