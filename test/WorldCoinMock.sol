// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IWorldID} from "@worldid/src/interfaces/IWorldID.sol";

contract WorldCoinMock is IWorldID {
    function verifyProof(
        uint256 root,
        uint256 signalHash,
        uint256 nullifierHash,
        uint256 externalNullifierHash,
        uint256[8] calldata proof
    ) external {
        return;
    }
}
