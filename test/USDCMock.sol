// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract USDCMock is ERC20Mock {
    function decimals() public view override returns (uint8) {
        return 18;
    }
}
