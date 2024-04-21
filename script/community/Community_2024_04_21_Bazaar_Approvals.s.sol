// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { CoveToken } from "cove-contracts-boosties/src/governance/CoveToken.sol";
import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";

contract Script is CommunityMultisigScript {
    // https://etherscan.io/address/0x47612eabFbE65329AeD1ab1BF3FCbAE493aEf460
    address private constant _BAZAAR_BATCH_AUCTION_FACTORY_ADDRESS = address(0x47612eabFbE65329AeD1ab1BF3FCbAE493aEf460);

    function run(bool shouldSend) public override {
        super.run(shouldSend);

        address coveToken = deployer.getAddress("CoveToken");

        // Start batch
        bytes memory ret = addToBatch(
            coveToken,
            0,
            abi.encodeCall(IERC20.approve, (address(_BAZAAR_BATCH_AUCTION_FACTORY_ADDRESS), uint256(95_000_000 ether)))
        );
        // Check return value
        require(abi.decode(ret, (bool)), "failed to approve");

        // Execute batch
        executeBatch(shouldSend);
    }
}
