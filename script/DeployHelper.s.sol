// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ZKoreLending} from "../src/ZKoreLending.sol";
import {Verifier} from "../src/zokrates/verifier.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployHelper is Script {
    function run() public returns (ZKoreLending, Verifier, address) {
        HelperConfig helper = new HelperConfig();
        (address worldCoinVerifier, address usdc) = helper.activeNetworkConfig();

        vm.startBroadcast();
        Verifier zokratesVerifier = new Verifier();
        address[] memory tokens = new address[](1);
        tokens[0] = address(0xFaF20830bCB78590EB1E183fD9cf42758B6c0c81);

        ZKoreLending instance = new ZKoreLending({
         _zokratesVerifier: address(zokratesVerifier),
         _tokenWhitelist: tokens,
         _worldId: worldCoinVerifier
        });
        vm.stopBroadcast();

        return (instance, zokratesVerifier, usdc);
    }
}
