// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ZKoreLending} from "../../src/ZKoreLending.sol";
import {DeployHelper} from "../../script/DeployHelper.s.sol";
import {Test} from "forge-std/Test.sol";

contract ZKoreLendingTest is Test {
    ZKoreLending instance;

    function setUp() public {
        DeployHelper deployerHelper = new DeployHelper();
        (instance,,) = deployerHelper.run();
    }

    function testDeposit() public {}
}
