// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Test} from "forge-std/Test.sol";
import {Deploy} from "script/Deploy.s.sol";

import {Comptroller} from "../src/core/Comptroller.sol";

import {CErc20Delegate, CToken} from "src/token/ERC20/CErc20Delegate.sol";
import {CErc20Delegator} from "src/token/ERC20/CErc20Delegator.sol";
import "../../src/token/interface/CTokenInterfaces.sol";
import {JumpRateModelV2} from "src/interestRate/JumpRateModelV2.sol";
import {Timelock} from "src/utils/Timelock.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract ComptrollerTest is Test {
    function setUp() public {
        Deploy deploy = new Deploy();
        (CErc20Delegate delegate, CErc20Delegator delegator, Timelock timelock, CToken[] memory alltokens, ERC20Mock usdt) = deploy.run();
    }
}
