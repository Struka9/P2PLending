// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {WorldCoinMock} from "../test/WorldCoinMock.sol";
import {USDCMock} from "../test/USDCMock.sol";

contract HelperConfig {
    struct NetworkConfig {
        address worldCoinVerifier;
        address usdc;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 8453) {
            activeNetworkConfig = getBaseGoerliConfig();
        } else {
            activeNetworkConfig = getAnvilConfigOrCreate();
        }
    }

    function getBaseGoerliConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            worldCoinVerifier: address(0x11cA3127182f7583EfC416a8771BD4d11Fae4334),
            usdc: address(0xF175520C52418dfE19C8098071a252da48Cd1C19)
        });
    }

    function getAnvilConfigOrCreate() internal returns (NetworkConfig memory) {
        if (activeNetworkConfig.worldCoinVerifier != address(0)) {
            return activeNetworkConfig;
        }

        WorldCoinMock mock = new WorldCoinMock();
        USDCMock usdcMock = new USDCMock();

        return NetworkConfig({worldCoinVerifier: address(mock), usdc: address(usdcMock)});
    }
}
