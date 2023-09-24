// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {USDCMock} from "../test/USDCMock.sol";
import {Script} from "forge-std/Script.sol";

contract DeployUSDC is Script {
    function run() public returns (address) {
        vm.startBroadcast(vm.envUint("PK"));
        USDCMock usdcMock = new USDCMock();
        vm.stopBroadcast();

        return address(usdcMock);
    }
}
