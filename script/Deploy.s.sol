// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Script, console} from "forge-std/Script.sol";
import {Comptroller} from "../src/core/Comptroller.sol";
import {CErc20Delegate, CToken} from "src/token/ERC20/CErc20Delegate.sol";
import {CErc20Delegator} from "src/token/ERC20/CErc20Delegator.sol";
import "../../src/token/interface/CTokenInterfaces.sol";
import {JumpRateModelV2} from "src/interestRate/JumpRateModelV2.sol";
import {Timelock} from "src/utils/Timelock.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract Deploy is Script {
    Comptroller comptroller;

    //interestRateModel
    uint256 baseRatePerYear = 2e16; //2%
    uint256 multiplierPerYear = 2e17; //20%
    uint256 jumpMultiplierPerYear = 1e18; //100%
    uint256 kink = 8e17; //80%
    address owner = msg.sender;

    function run() public returns (CErc20Delegate, CErc20Delegator, Timelock, CToken[] memory, ERC20Mock) {
        vm.startBroadcast();
        ERC20Mock usdt = new ERC20Mock();
        Comptroller comptroller = deployComptroller();
        (CErc20Delegate delegate, CErc20Delegator delegator, Timelock timelock) =
            deployDelegateAndDelegator(address(usdt));
        Comptroller(comptroller)._supportMarket(CToken(address(delegator)));

        vm.stopBroadcast();
        CToken[] memory alltokens = Comptroller(comptroller).getAllMarkets();
        return (delegate, delegator, timelock, alltokens, usdt);
    }

    //step 1 deploy comptroller

    function deployComptroller() public returns (Comptroller) {
        Comptroller comptroller = new Comptroller();
        return comptroller;
    }

    // step 2 deploy interestRateModel

    function interestRateModel() public returns (JumpRateModelV2) {
        JumpRateModelV2 interestRateModel =
            new JumpRateModelV2(baseRatePerYear, multiplierPerYear, jumpMultiplierPerYear, kink, owner);
        return interestRateModel;
    }

    // step 3 deploy delegate and delegator
    function deployDelegateAndDelegator(address _usdt) public returns (CErc20Delegate, CErc20Delegator, Timelock) {
        uint256 delay_ = 3 * 24 * 60 * 60; // 3 days in seconds
        Timelock timelock = new Timelock(owner, delay_);
        address underlying_ = _usdt;
        ComptrollerInterface comptroller_ = deployComptroller();
        InterestRateModel interestRateModel_ = interestRateModel();
        uint256 initialExchangeRateMantissa_ = 1e18; // 1:1
        string memory name_ = "CUSDT";
        string memory symbol_ = "CUSDT";
        uint8 decimals_ = 8;
        address payable admin_ = payable(address(timelock));
        //  address implementation_;
        bytes memory becomeImplementationData;
        CErc20Delegate delegate = new CErc20Delegate();
        CErc20Delegator delegator = new CErc20Delegator(
            underlying_,
            comptroller_,
            interestRateModel_,
            initialExchangeRateMantissa_,
            name_,
            symbol_,
            decimals_,
            admin_,
            address(delegate), // implementation_,
            becomeImplementationData
        );

        return (delegate, delegator, timelock);
    }
}
