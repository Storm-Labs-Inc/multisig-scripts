// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { IAccessControl } from
    "lib/cove-contracts-boosties/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { CoveYearnGaugeFactory } from "lib/cove-contracts-boosties/src/registries/CoveYearnGaugeFactory.sol";
import { ERC20RewardsGauge } from "lib/cove-contracts-boosties/src/rewards/ERC20RewardsGauge.sol";

contract Script is CommunityMultisigScript, StdAssertions {
    address constant NEW_KEEPER = 0xd31336617fC8B5Ee3b162d88e75B9236a9be3d6D;

    function run(bool shouldSend) public override {
        super.run(shouldSend);

        CoveYearnGaugeFactory factory = CoveYearnGaugeFactory(deployer.getAddress("CoveYearnGaugeFactory"));
        CoveYearnGaugeFactory.GaugeInfo[] memory info = factory.getAllGaugeInfo(100, 0);
        address coveToken = deployer.getAddress("CoveToken");

        address[] memory rewardForwarders = new address[](info.length * 2 + 1);

        // Get all reward forwarders
        for (uint256 i = 0; i < info.length; i++) {
            rewardForwarders[i * 2] =
                ERC20RewardsGauge(info[i].autoCompoundingGauge).getRewardData(coveToken).distributor;
            rewardForwarders[i * 2 + 1] =
                ERC20RewardsGauge(info[i].nonAutoCompoundingGauge).getRewardData(coveToken).distributor;
        }
        // Add the CoveYFIRewardsGaugeRewardForwarder to the list
        rewardForwarders[info.length * 2] = deployer.getAddress("CoveYFIRewardsGaugeRewardForwarder");

        // ================================ START BATCH ===================================
        // Add to batch

        // Grant MANAGER_ROLE to NEW_KEEPER for all reward forwarders
        for (uint256 i = 0; i < rewardForwarders.length; i++) {
            addToBatch(rewardForwarders[i], abi.encodeCall(IAccessControl.grantRole, (MANAGER_ROLE, NEW_KEEPER)));
        }

        // ================================ TESTING ===================================
        // Testing will be done in the simulation when executing the batch

        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true);
        }
    }
}
