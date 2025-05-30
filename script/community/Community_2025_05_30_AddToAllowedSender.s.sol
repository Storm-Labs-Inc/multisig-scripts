// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { TimelockController } from
    "lib/cove-contracts-boosties/lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";
import { CoveToken } from "cove-contracts-boosties/src/governance/CoveToken.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

interface IFarmingPlugin {
    function setDistributor(address distributor) external;
    function startFarming(uint256 amount, uint256 duration) external;
    function farmInfo() external view returns (uint40 finished, uint32 duration, uint184 reward, uint256 balance);
}

contract Script is CommunityMultisigScript, StdAssertions, StdCheats {
    address public coveUSDFarmingPlugin = 0xa74e0B738b053D9083451bBAB84c538ff2Cc701d;

    function run() public {
        run(false);
    }

    function run(bool shouldSend) public override {
        super.run(shouldSend);

        IFarmingPlugin farmingPlugin = IFarmingPlugin(coveUSDFarmingPlugin);
        address timelock = deployer.getAddress("TimelockController");
        address coveToken = deployer.getAddress("CoveToken");

        // ================================ START BATCH ===================================

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory payloads = new bytes[](1);

        // Approve auction contract to send COVE so participants can claim COVE after the auction ends
        targets[0] = coveToken;
        payloads[0] = abi.encodeCall(CoveToken.addAllowedSender, (address(farmingPlugin)));
        values[0] = 0;

        addToBatch(
            timelock,
            0,
            abi.encodeCall(
                TimelockController.scheduleBatch, (targets, values, payloads, bytes32(0), bytes32(0), 2 days)
            )
        );

        // ============================= TESTING ===================================
        vm.warp(block.timestamp + 2 days + 1);
        vm.prank(MAINNET_COVE_DEPLOYER);
        TimelockController(payable(timelock)).executeBatch(targets, values, payloads, bytes32(0), bytes32(0));
        require(CoveToken(coveToken).allowedSender(address(farmingPlugin)), "farmingPlugin is not allowed to send");

        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true);
        }
    }
}
