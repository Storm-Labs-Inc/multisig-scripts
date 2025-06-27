// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { OpsMultisigScript } from "./OpsMultisigScript.s.sol";
import { StdAssertions } from "forge-std/StdAssertions.sol";
import { TokenizedStrategy } from "lib/cove-contracts-boosties/lib/tokenized-strategy/src/TokenizedStrategy.sol";
import { IAccessControl } from
    "lib/cove-contracts-boosties/lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { CoveYearnGaugeFactory } from "lib/cove-contracts-boosties/src/registries/CoveYearnGaugeFactory.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFarmingPlugin {
    function setDistributor(address distributor) external;
    function startFarming(uint256 amount, uint256 duration) external;
    function farmInfo() external view returns (uint40 finished, uint32 duration, uint184 reward, uint256 balance);
}

contract Script is OpsMultisigScript, StdAssertions {
    address public coveUSDFarmingPlugin = 0xa74e0B738b053D9083451bBAB84c538ff2Cc701d;
    address public coveToken = 0x32fb7D6E0cBEb9433772689aA4647828Cc7cbBA8;

    uint256 public constant REWARD_AMOUNT_PER_WEEK = 182_700 * 1e18;
    uint256 public constant TOTAL_DURATION = 28 days;

    function run() public {
        run(false);
    }

    function run(bool shouldSend) public override {
        super.run(shouldSend);

        IFarmingPlugin farmingPlugin = IFarmingPlugin(coveUSDFarmingPlugin);
        uint256 totalRewardAmount = REWARD_AMOUNT_PER_WEEK * TOTAL_DURATION / 7 days;

        // ================================ START BATCH ===================================
        (uint40 finished, uint32 duration, uint184 reward, uint256 balance) = farmingPlugin.farmInfo();

        addToBatch(coveToken, 0, abi.encodeCall(IERC20.approve, (address(farmingPlugin), totalRewardAmount)));
        addToBatch(
            coveUSDFarmingPlugin, 0, abi.encodeCall(IFarmingPlugin.startFarming, (totalRewardAmount, TOTAL_DURATION))
        );

        (finished, duration, reward, balance) = farmingPlugin.farmInfo();
        uint256 perWeek = reward * 7 days / TOTAL_DURATION;

        require(perWeek == REWARD_AMOUNT_PER_WEEK, "perWeek is not equal to REWARD_AMOUNT_PER_WEEK");

        // ============================= QUEUE UP MSIG ================================
        if (shouldSend) {
            executeBatch(true);
        }
    }
}
