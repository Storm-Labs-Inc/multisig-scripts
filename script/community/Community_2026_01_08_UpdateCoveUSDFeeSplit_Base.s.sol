// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { TimelockController } from
    "lib/cove-contracts-boosties/lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";

interface IBasketManager {
    function setManagementFee(address basket, uint16 managementFeeBps) external;
    function managementFee(address basket) external view returns (uint16);
}

interface IFeeCollector {
    function setSponsorSplit(address basketToken, uint16 sponsorSplit) external;
    function basketTokenSponsorSplits(address basketToken) external view returns (uint16);
    function basketTokenSponsors(address basketToken) external view returns (address);
}

contract Script is CommunityMultisigScript, StdAssertions {
    address public constant BASE_BASKET_MANAGER = 0x2Cd0a6e0527a80B058FDDCc1A7C10F00cc18890f;
    address public constant BASE_FEE_COLLECTOR = 0x6d0Ba3f757a479320700E69e9Ae5768D61aD8041;
    address public constant BASE_COVEUSD_BASKET_TOKEN = 0x41fF35767Ee48f57CE659F6390809185Dcf9b0f9;
    address public constant BASE_TIMELOCK_CONTROLLER = 0x06B3f124c25873E4dDc54B762F24dD5A13a5d58e;

    uint16 public constant NEW_MANAGEMENT_FEE_BPS = 80; // 0.80%
    uint16 public constant NEW_SPONSOR_SPLIT_BPS = 3750; // 37.5% of 0.80% = 0.30%

    function run() public {
        run(false);
    }

    function run(bool shouldSend) public override {
        super.run(shouldSend);

        TimelockController timelock = TimelockController(payable(BASE_TIMELOCK_CONTROLLER));
        uint256 delay = timelock.getMinDelay();

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory payloads = new bytes[](1);

        targets[0] = BASE_BASKET_MANAGER;
        values[0] = 0;
        payloads[0] = abi.encodeCall(
            IBasketManager.setManagementFee,
            (BASE_COVEUSD_BASKET_TOKEN, NEW_MANAGEMENT_FEE_BPS)
        );

        addToBatch(
            BASE_FEE_COLLECTOR,
            0,
            abi.encodeCall(
                IFeeCollector.setSponsorSplit,
                (BASE_COVEUSD_BASKET_TOKEN, NEW_SPONSOR_SPLIT_BPS)
            )
        );

        addToBatch(
            BASE_TIMELOCK_CONTROLLER,
            0,
            abi.encodeCall(
                TimelockController.scheduleBatch,
                (targets, values, payloads, bytes32(0), bytes32(0), delay)
            )
        );

        // ============================= TESTING (fork only) =============================
        vm.warp(block.timestamp + delay);
        vm.prank(MAINNET_COVE_DEPLOYER);
        timelock.executeBatch(targets, values, payloads, bytes32(0), bytes32(0));

        assertEq(
            IBasketManager(BASE_BASKET_MANAGER).managementFee(BASE_COVEUSD_BASKET_TOKEN),
            NEW_MANAGEMENT_FEE_BPS,
            "management fee not updated"
        );
        assertEq(
            IFeeCollector(BASE_FEE_COLLECTOR).basketTokenSponsorSplits(BASE_COVEUSD_BASKET_TOKEN),
            NEW_SPONSOR_SPLIT_BPS,
            "sponsor split not updated"
        );

        // if context is ScriptBroadcast (forge script ... --broadcast),
        // actually execute the batch
        // otherwise, just simulate the batch
        if (vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) {
            executeBatch(true);
        } else {
            executeBatch(false);
        }
    }
}
