// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { CoveYearnGaugeFactory } from "lib/cove-contracts-boosties/src/registries/CoveYearnGaugeFactory.sol";
import { YearnStakingDelegate } from "lib/cove-contracts-boosties/src/YearnStakingDelegate.sol";
import { TimelockController } from
    "lib/cove-contracts-boosties/lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";
import { IERC4626 } from "lib/cove-contracts-boosties/lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

interface IFarmingPlugin {
    function setDistributor(address distributor) external;
    function startFarming(uint256 amount, uint256 duration) external;
    function farmInfo() external view returns (uint40 finished, uint32 duration, uint184 reward, uint256 balance);
}

contract Script is CommunityMultisigScript, StdAssertions, StdCheats {
    uint256 public constant REWARD_AMOUNT_PER_WEEK = 182_700 * 1e18;
    uint256 public constant TOTAL_DURATION = 28 days;

    address public coveUSDFarmingPlugin = 0xa74e0B738b053D9083451bBAB84c538ff2Cc701d;
    address public coveToken = 0x32fb7D6E0cBEb9433772689aA4647828Cc7cbBA8;

    function run() public {
        run(false);
    }

    function run(bool shouldSend) public override {
        super.run(shouldSend);

        IFarmingPlugin farmingPlugin = IFarmingPlugin(coveUSDFarmingPlugin);
        uint256 totalRewardAmount = REWARD_AMOUNT_PER_WEEK * TOTAL_DURATION / 7 days;

        // ================================ START BATCH ===================================

        addToBatch(
            address(farmingPlugin), 0, abi.encodeCall(IFarmingPlugin.setDistributor, (MAINNET_COVE_OPS_MULTISIG))
        );
        addToBatch(
            address(coveToken), 0, abi.encodeCall(IERC20.transfer, (MAINNET_COVE_OPS_MULTISIG, totalRewardAmount))
        );

        // ============================= TESTING ===================================
        (uint40 finished, uint32 duration, uint184 reward, uint256 balance) = farmingPlugin.farmInfo();

        vm.prank(MAINNET_COVE_OPS_MULTISIG);
        IERC20(coveToken).approve(address(farmingPlugin), totalRewardAmount);
        vm.prank(MAINNET_COVE_OPS_MULTISIG);
        farmingPlugin.startFarming(totalRewardAmount, TOTAL_DURATION);

        (finished, duration, reward, balance) = farmingPlugin.farmInfo();
        uint256 perWeek = reward * 7 days / TOTAL_DURATION;

        require(perWeek == REWARD_AMOUNT_PER_WEEK, "perWeek is not equal to REWARD_AMOUNT_PER_WEEK");

        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true, 22);
        }
    }
}
