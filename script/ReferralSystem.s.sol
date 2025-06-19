// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import {ReferralSystem} from "../src/ReferralSystem.sol";

contract DeployReferralSystem is Script {
    function run () external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ReferralSystem referralSystem = new ReferralSystem(500); // 5% fee

        vm.stopBroadcast();

        console.log("ReferralSystem deployed at:", address(referralSystem));
         }
}