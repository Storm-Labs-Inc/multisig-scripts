// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { CoveYearnGaugeFactory } from "cove-contracts-boosties/src/registries/CoveYearnGaugeFactory.sol";
import { YearnGaugeStrategy } from "cove-contracts-boosties/src/strategies/YearnGaugeStrategy.sol";

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
    function run(bool shouldSend) public override {
        super.run(shouldSend);
        address swapAndLock = 0x9dadf9487737DE29ac685d231bB94348a2635CBb;
        address dyfiRedeemerV2 = 0x0000000000000000000000000000000000000000;
        address dyfiRedeemer = 0x986F38B5b096070eE64B12Da762468606C8B0706;
        address masterRegistry = 0x91cf20C03bEC656BC008fB2a2177bC3caA34f772;
        // Fetch all Yearn gauge info from the factory
        CoveYearnGaugeFactory factory = CoveYearnGaugeFactory(deployer.getAddress("CoveYearnGaugeFactory"));
        CoveYearnGaugeFactory.GaugeInfo[] memory gauges = factory.getAllGaugeInfo(100, 0);
        // ================================ START BATCH ===================================
        // Add to batch - update SwapAndLock contract
        addToBatch(swapAndLock, 0, abi.encodeCall(ISwapAndLock.setDYfiRedeemer, dyfiRedeemerV2));
        // Update every YearnGaugeStrategy with the new (placeholder) redeemer address
        for (uint256 i = 0; i < gauges.length; i++) {
            addToBatch(
                gauges[i].coveYearnStrategy,
                0,
                abi.encodeCall(YearnGaugeStrategy.setDYfiRedeemer, (dyfiRedeemerV2))
            );
        }
        // Kill old redeemer
        addToBatch(dyfiRedeemer, 0, abi.encodeCall(IDYFIRedeemer.kill, ()));
        // Add new contract to master registry
        // TODO: should be a new entry or update the existing one?
        addToBatch(
            masterRegistry,
            0,
            abi.encodeCall(IMasterRegistry.addRegistry, (keccak256("DYFIRedeemer"), dyfiRedeemerV2))
        );
        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true);
        }
    }
}
