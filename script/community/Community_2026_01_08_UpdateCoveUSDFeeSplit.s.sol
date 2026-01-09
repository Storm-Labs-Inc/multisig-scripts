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
    address public constant MAINNET_BASKET_MANAGER = 0x716c39658Ba56Ce34bdeCDC1426e8768E61912f8;
    address public constant MAINNET_FEE_COLLECTOR = 0x9219401e7E2e473770E56203e4EebA85083C7f7E;
    address public constant MAINNET_COVEUSD_BASKET_TOKEN = 0xEeA3Edc017877C603E2F332FC1828a46432cdF96;
    address public constant MAINNET_TIMELOCK_CONTROLLER = 0x705F82BB431fAdA1a0F11D7b77B3f0586c545CBc;

    uint16 public constant NEW_MANAGEMENT_FEE_BPS = 80; // 0.80%
    uint16 public constant NEW_SPONSOR_SPLIT_BPS = 3750; // 37.5% of 0.80% = 0.30%

    function run() public {
        run(false);
    }

    function run(bool shouldSend) public override {
        super.run(shouldSend);

        TimelockController timelock = TimelockController(payable(MAINNET_TIMELOCK_CONTROLLER));
        uint256 delay = timelock.getMinDelay();

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory payloads = new bytes[](1);

        targets[0] = MAINNET_BASKET_MANAGER;
        values[0] = 0;
        payloads[0] = abi.encodeCall(
            IBasketManager.setManagementFee,
            (MAINNET_COVEUSD_BASKET_TOKEN, NEW_MANAGEMENT_FEE_BPS)
        );

        addToBatch(
            MAINNET_FEE_COLLECTOR,
            0,
            abi.encodeCall(
                IFeeCollector.setSponsorSplit,
                (MAINNET_COVEUSD_BASKET_TOKEN, NEW_SPONSOR_SPLIT_BPS)
            )
        );

        addToBatch(
            MAINNET_TIMELOCK_CONTROLLER,
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
            IBasketManager(MAINNET_BASKET_MANAGER).managementFee(MAINNET_COVEUSD_BASKET_TOKEN),
            NEW_MANAGEMENT_FEE_BPS,
            "management fee not updated"
        );
        assertEq(
            IFeeCollector(MAINNET_FEE_COLLECTOR).basketTokenSponsorSplits(MAINNET_COVEUSD_BASKET_TOKEN),
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
