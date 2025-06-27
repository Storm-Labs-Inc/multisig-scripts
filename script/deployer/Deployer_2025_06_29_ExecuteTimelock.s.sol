// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CoveToken } from "lib/cove-contracts-boosties/src/governance/CoveToken.sol";
import { DeployerScript } from "./DeployerScript.s.sol";
import { TimelockController } from
    "lib/cove-contracts-boosties/lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";

// Execute the timelock transaction scheduled by Community_2025_06_27_TransferLMRewardsMerkl
// This will call CoveToken.addAllowedSender(merklDistributor) to allow Merkl to distribute COVE tokens
contract Script is DeployerScript {
    address constant MERKL_DISTRIBUTOR = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae;

    function run() public override {
        super.run();
        vm.startBroadcast(MAINNET_COVE_DEPLOYER);

        address coveToken = deployer.getAddress("CoveToken");
        address timelock = deployer.getAddress("TimelockController");

        // Execute the scheduled timelock transaction
        address target = coveToken;
        uint256 value = 0;
        bytes memory payload = abi.encodeCall(CoveToken.addAllowedSender, (MERKL_DISTRIBUTOR));

        TimelockController(payable(timelock)).execute(target, value, payload, bytes32(0), bytes32(0));

        vm.stopBroadcast();
    }
}
