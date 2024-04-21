// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { CoveToken } from "cove-contracts-boosties/src/governance/CoveToken.sol";
import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";

contract Script is CommunityMultisigScript {
    // https://etherscan.io/address/0x47612eabFbE65329AeD1ab1BF3FCbAE493aEf460
    address private constant _BAZAAR_BATCH_AUCTION_FACTORY_ADDRESS = address(0x47612eabFbE65329AeD1ab1BF3FCbAE493aEf460);
    // https://etherscan.io/address/0x32fb7D6E0cBEb9433772689aA4647828Cc7cbBA8
    address private constant _COVE_TOKEN_ADDRESS = address(0x32fb7D6E0cBEb9433772689aA4647828Cc7cbBA8);

    function run(bool shouldSend) public override {
        // Start batch
        bytes memory ret = addToBatch(
            _COVE_TOKEN_ADDRESS,
            uint256(95_000_000 ether),
            abi.encodeWithSelector(IERC20.approve.selector, address(_BAZAAR_BATCH_AUCTION_FACTORY_ADDRESS), 1)
        );
        // Check return value
        require(abi.decode(ret, (bool)), "failed to approve");

        ret = addToBatch(
            _COVE_TOKEN_ADDRESS,
            0,
            abi.encodeWithSelector(CoveToken.addAllowedSender.selector, _BAZAAR_BATCH_AUCTION_FACTORY_ADDRESS)
        );
        require(
            CoveToken(_COVE_TOKEN_ADDRESS).allowedSender(_BAZAAR_BATCH_AUCTION_FACTORY_ADDRESS) == true,
            "failed to allow sender"
        );

        // Execute batch
        executeBatch(shouldSend);
    }
}
