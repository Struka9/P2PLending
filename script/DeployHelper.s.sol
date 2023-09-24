// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ZKoreLending} from "../src/ZKoreLending.sol";
import {Verifier} from "../src/zokrates/verifier.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployHelper is Script {
    function run() public returns (ZKoreLending, Verifier) {
        Verifier zokratesVerifier = new Verifier();

        HelperConfig helper = new HelperConfig();
        (address worldCoinVerifier, address usdc) = helper.activeNetworkConfig();

        address[] memory tokens = new address[](1);
        tokens[0] = usdc;

        ZKoreLending instance = new ZKoreLending({
         _zokratesVerifier: address(zokratesVerifier),
         _tokenWhitelist: tokens,
         _worldId: worldCoinVerifier
        });

        return (instance, zokratesVerifier);
    }
}
