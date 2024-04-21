// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BatchScript } from "forge-safe/BatchScript.sol";
import { Constants } from "cove-contracts-boosties/test/utils/Constants.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract CommunityMultisigScript is BatchScript, Constants {
    function run(bool) public virtual isBatch(MAINNET_COVE_COMMUNITY_MULTISIG) {
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
