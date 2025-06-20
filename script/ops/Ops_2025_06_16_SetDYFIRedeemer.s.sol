// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { OpsMultisigScript } from "./OpsMultisigScript.s.sol";
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

contract Script is OpsMultisigScript, StdAssertions {
    function run() public {
        run(false);
    }

    function run(bool shouldSend) public override {
        super.run(shouldSend);
        address dyfiRedeemerV2 = 0x17072491906E25323175454044642054d97767Fd;
        address dyfiRedeemer = deployer.getAddress("DYFIRedeemer");
        // Fetch all Yearn gauge info from the factory
        CoveYearnGaugeFactory factory = CoveYearnGaugeFactory(deployer.getAddress("CoveYearnGaugeFactory"));
        CoveYearnGaugeFactory.GaugeInfo[] memory gauges = factory.getAllGaugeInfo(100, 0);

        // ================================ START BATCH ===================================
        // Claim management role from usds strategy
        address usds1 = deployer.getAddress("YearnGaugeStrategy-yGauge USDS-1 yVault");
        addToBatch(usds1, 0, abi.encodeCall(ITokenizedStrategy.acceptManagement, ()));
        // Update every YearnGaugeStrategy with the new (placeholder) redeemer address
        for (uint256 i = 0; i < gauges.length; i++) {
            // address management = ITokenizedStrategy(gauges[i].coveYearnStrategy).management();
            addToBatch(
                gauges[i].coveYearnStrategy, 0, abi.encodeCall(YearnGaugeStrategy.setDYfiRedeemer, (dyfiRedeemerV2))
            );
        }

        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true);
        }
    }
}
