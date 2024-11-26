// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Script, console} from "forge-std/Script.sol";
import {Comptroller} from "../src/core/Comptroller.sol";
import {CErc20Delegate, CToken} from "src/token/ERC20/CErc20Delegate.sol";
import {CErc20Delegator} from "src/token/ERC20/CErc20Delegator.sol";
import "../../src/token/interface/CTokenInterfaces.sol";
import {JumpRateModelV2} from "src/interestRate/JumpRateModelV2.sol";
import {PriceOracle} from "src/PriceOracle/PriceOracle.sol";
import {Timelock} from "src/utils/Timelock.sol";
import {SimplePriceOracle} from "src/PriceOracle/SimplePriceOracle.sol";
import {CToken} from "src/token/CToken.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract Deploy is Script {
    Comptroller comptroller;

    //interestRateModel
    uint256 baseRatePerYear = 2e16; //2%
    uint256 multiplierPerYear = 2e17; //20%
    uint256 jumpMultiplierPerYear = 1e18; //100%
    uint256 kink = 8e17; //80%
    address owner = msg.sender;

    function run()
        public
        returns (Comptroller, CErc20Delegator, CErc20Delegator, Timelock, CToken[] memory, ERC20Mock, ERC20Mock)
    {
        vm.startBroadcast();

        //USDT
        ERC20Mock usdt = new ERC20Mock();
        string memory nameusdt = "USDT";
        string memory symbolusdt = "USDT";
        uint8 decimalsusdt = 18;

        //USDC
        ERC20Mock usdc = new ERC20Mock();
        string memory nameusdc = "USDC";
        string memory symbolusdc = "USDC";
        uint8 decimalsusdc = 6;

        uint256 delay_ = 3 * 24 * 60 * 60; // 3 days in seconds
        Timelock timelock = new Timelock(owner, delay_);

        Comptroller comptroller = deployComptroller();

        // Set up the oracle first
        SimplePriceOracle oracle = new SimplePriceOracle();
        comptroller._setPriceOracle(oracle);

        (ERC20Mock usdttoken, CErc20Delegator cusdttoken) =
            deployToken(comptroller, timelock, oracle, nameusdt, symbolusdt, decimalsusdt);

        (ERC20Mock usdctoken, CErc20Delegator cusdctoken) =
            deployToken(comptroller, timelock, oracle, nameusdc, symbolusdc, decimalsusdc);

        vm.stopBroadcast();
        CToken[] memory alltokens = Comptroller(comptroller).getAllMarkets();

        return (comptroller, cusdttoken, cusdctoken, timelock, alltokens, usdttoken, usdctoken);
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

    function deployToken(
        Comptroller comptroller,
        Timelock timelock,
        SimplePriceOracle oracle,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) public returns (ERC20Mock, CErc20Delegator) {
        //USDT
        ERC20Mock usdt = new ERC20Mock();

        (CErc20Delegate delegate, CErc20Delegator delegator) =
            deployDelegateAndDelegator(address(usdt), comptroller, timelock, name, symbol, decimals);

        // Set the price for USDT (1 USDT = 1 USD, with 18 decimals)
        oracle.setDirectPrice(address(usdt), 1e18);

        // Support the market
        comptroller._supportMarket(CToken(address(delegator)));

        // Set market parameters
        uint256 collateralFactorMantissa = 0.75 * 1e18; // 75%
        comptroller._setCollateralFactor(CToken(address(delegator)), collateralFactorMantissa);

        // Set close factor
        uint256 closeFactorMantissa = 0.5 * 1e18; // 50%
        comptroller._setCloseFactor(closeFactorMantissa);

        return (usdt, delegator);
    }

    // step 3 deploy delegate and delegator
    function deployDelegateAndDelegator(
        address _usdt,
        Comptroller _comptroller,
        Timelock _timelock,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) public returns (CErc20Delegate, CErc20Delegator) {
        address underlying_ = _usdt;
        ComptrollerInterface comptroller_ = _comptroller;
        InterestRateModel interestRateModel_ = interestRateModel();
        uint256 initialExchangeRateMantissa_ = 1e18; // 1:1
        string memory name_ = _name;
        string memory symbol_ = _symbol;
        uint8 decimals_ = _decimals;
        address payable admin_ = payable(address(_timelock));
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

        return (delegate, delegator);
    }
}
