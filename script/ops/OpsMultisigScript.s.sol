// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BatchScript} from "forge-safe/BatchScript.sol";
import {Constants} from "cove-contracts-boosties/test/utils/Constants.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract OpsMultisigScript is BatchScript, Constants {
    function run(bool shouldSend) public virtual isBatch(MAINNET_COVE_OPS_MULTISIG) {
        // Example

        // Start batch
        // bytes memory ret = addToBatch(address(MAINNET_YFI), 0, abi.encodeWithSelector(
        //     IERC20.approve.selector,
        //     address(0xdead),
        //     1
        // ));
        // Check return value
        // require(abi.decode(ret, (bool)), "failed to approve");

        // ret = addToBatch(address(MAINNET_YFI), 0, abi.encodeWithSelector(
        //     IERC20.approve.selector,
        //     address(0xdead),
        //     0
        // ));
        // require(abi.decode(ret, (bool)), "failed to approve");

        // Execute batch
        // executeBatch(shouldSend);
    }
}
