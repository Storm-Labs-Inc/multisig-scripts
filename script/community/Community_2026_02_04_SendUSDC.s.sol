// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";

contract Script is CommunityMultisigScript {
    address public constant RECIPIENT = 0x581678F6D676dbD0ba57251324613aB48E9E28Db;
    uint256 public constant USDC_AMOUNT = 50_000 * 1e6; // USDC has 6 decimals

    function run(bool shouldSend) public override {
        super.run(shouldSend);

        addToBatch(MAINNET_USDC, 0, abi.encodeCall(IERC20.transfer, (RECIPIENT, USDC_AMOUNT)));

        if (shouldSend) executeBatch(true);
    }
}
