// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { CoveToken } from "cove-contracts-boosties/src/governance/CoveToken.sol";
import { CommunityMultisigScript } from "./CommunityMultisigScript.s.sol";
import { console2 as console } from "forge-std/console2.sol";

struct BatchAuctionUncappedConfig {
    IERC20 projectToken; // coveToken
    IERC20 quoteToken; // weth 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2
    uint256 projectTokenAmount; // 95_000_000 ether
    uint256 floorQuoteAmount; // 903.66603 ether
    uint256 startTime; // 1713758400
    uint256 endTime; // 1714017600
}

interface BazaarBatchAuctionFactory {
    function createAuction(BatchAuctionUncappedConfig memory cfg) external returns (BazaarAuction);
}

interface BazaarAuction {
    function subscribe(address subscriber, uint256 amount) external payable;
    function claimProjectToken() external;
    function claimAuctioneerTokens() external;
}

contract Script is CommunityMultisigScript {
    // https://etherscan.io/address/0x47612eabFbE65329AeD1ab1BF3FCbAE493aEf460
    address private constant _BAZAAR_BATCH_AUCTION_FACTORY_ADDRESS = address(0x47612eabFbE65329AeD1ab1BF3FCbAE493aEf460);
    address private constant _WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    uint256 private constant _START_TIME = 1_713_758_400;
    uint256 private constant _END_TIME = 1_714_017_600;

    function run(bool shouldSend) public override {
        super.run(shouldSend);

        address coveToken = deployer.getAddress("CoveToken");
        address timelock = deployer.getAddress("TimelockController");

        // Start batch
        // Check approval. Already queued up in the batch so prank and approve
        if (
            IERC20(coveToken).allowance(
                address(MAINNET_COVE_COMMUNITY_MULTISIG), address(_BAZAAR_BATCH_AUCTION_FACTORY_ADDRESS)
            ) < 95_000_000 ether
        ) {
            vm.prank(MAINNET_COVE_COMMUNITY_MULTISIG);
            bool isApproved =
                IERC20(coveToken).approve(address(_BAZAAR_BATCH_AUCTION_FACTORY_ADDRESS), 95_000_000 ether);
            // Check return value
            require(isApproved, "failed to approve");
        }

        // Create auction
        vm.prank(MAINNET_COVE_COMMUNITY_MULTISIG);
        BazaarAuction auction = BazaarBatchAuctionFactory(_BAZAAR_BATCH_AUCTION_FACTORY_ADDRESS).createAuction(
            BatchAuctionUncappedConfig(
                IERC20(coveToken), IERC20(_WETH), 95_000_000 ether, 903.66603 ether, _START_TIME, _END_TIME
            )
        );
        console.log("auction created at: %s", address(auction));

        // Testing auctions

        // Once the auction is created, we must approve the auction contract as a sender via Timelock
        // @multisig: This will be queued after creating the auction.
        vm.prank(timelock);
        CoveToken(coveToken).addAllowedSender(address(auction));
        // Warp to auction start time
        vm.warp(_START_TIME + 1);
        // Subscribe to auction with 1 ether commitment
        vm.deal(address(0xbeef), 1 ether);
        vm.startPrank(address(0xbeef));
        auction.subscribe{ value: 1 ether }(address(0xbeef), 1 ether);

        // Warp to auction end time
        vm.warp(_END_TIME + 1);
        // Claim project token
        auction.claimProjectToken();
        require(IERC20(coveToken).balanceOf(address(0xbeef)) > 0, "failed to claim project token");
        vm.stopPrank();
        vm.prank(MAINNET_COVE_COMMUNITY_MULTISIG);
        auction.claimAuctioneerTokens();
        // Check if auctioneer tokens are claimed
        require(MAINNET_COVE_COMMUNITY_MULTISIG.balance > 0, "failed to claim auctioneer tokens");

        // Execute batch
        // executeBatch(shouldSend);
    }
}
