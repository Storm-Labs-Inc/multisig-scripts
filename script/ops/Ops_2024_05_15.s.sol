// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC4626 } from "@openzeppelin/contracts/token/ERC20/Extensions/ERC4626.sol";
import { OpsMultisigScript } from "./OpsMultisigScript.s.sol";

contract Script is OpsMultisigScript {
    function run(bool shouldSend) public override {
        super.run(shouldSend);

        address yfi = MAINNET_YFI;
        address coveYfi = deployer.getAddress("CoveYFI");

        // approve yfi
        addToBatch(yfi, 0, abi.encodeCall(IERC20.approve, (coveYfi, type(uint256).max)));
        addToBatch(coveYfi, 0, abi.encodeCall(IERC4626.deposit, (14.8049067e18, MAINNET_COVE_OPS_MULTISIG)));
        // 14.8049067e18
        // Execute batch
        if (shouldSend) executeBatch(true);
    }
}
