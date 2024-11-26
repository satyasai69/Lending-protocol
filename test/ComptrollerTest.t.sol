// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {Test, console} from "forge-std/Test.sol";
import {Deploy} from "script/Deploy.s.sol";

import {Comptroller} from "../src/core/Comptroller.sol";

import {CToken} from "src/token/CToken.sol";

import {CErc20Delegate, CToken} from "src/token/ERC20/CErc20Delegate.sol";
import {CErc20Delegator} from "src/token/ERC20/CErc20Delegator.sol";
import "../../src/token/interface/CTokenInterfaces.sol";
import {JumpRateModelV2} from "src/interestRate/JumpRateModelV2.sol";
import {Timelock} from "src/utils/Timelock.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {PriceOracle} from "src/PriceOracle/PriceOracle.sol";

contract ComptrollerTest is Test {
    Comptroller comptroller;
    CErc20Delegator delegatorusdc;
    CErc20Delegator delegator;
    Timelock timelock;
    CToken[] alltokens;
    ERC20Mock usdt;
    ERC20Mock usdc;

    address user = makeAddr("USER");
    address admin = address(this);

    function setUp() public {
        Deploy deploy = new Deploy();
        (
            Comptroller _comptroller,
            CErc20Delegator _delegator,
            CErc20Delegator _delegatorusdc,
            Timelock _timelock,
            CToken[] memory _alltokens,
            ERC20Mock _usdt,
            ERC20Mock _usdc
        ) = deploy.run();
        
        comptroller = _comptroller;
        delegator = _delegator;
        delegatorusdc = _delegatorusdc;
        timelock = _timelock;
        alltokens = _alltokens;
        usdt = _usdt;
        usdc = _usdc;

        // Mint tokens to user for testing
        usdt.mint(user, 10 ether);
       // usdc.mint(user, 10 ether);

        // Mint and supply tokens as admin (this contract)
        usdt.mint(admin, 100 ether);
        usdc.mint(admin, 100 ether);

        // Approve spending by cToken contracts
        usdt.approve(address(delegator), 100 ether);
        usdc.approve(address(delegatorusdc), 100 ether);

        // Mint cTokens (supply to protocol)
        delegator.mint(100 ether);
        delegatorusdc.mint(100 ether);

        // Fund user with ETH
        vm.deal(user, 100 ether);

        // Support markets in Comptroller
        comptroller._supportMarket(CToken(address(delegator)));
        comptroller._supportMarket(CToken(address(delegatorusdc)));
    }

    function testCheck() public returns (CToken[] memory) {
        console.log(alltokens.length, "alltokens", address(alltokens[0]));
        return alltokens;
    }

    function testUsdtInMarket() public {
        CToken[] memory alltokensInMarket = Comptroller(comptroller).getAllMarkets();

        assertEq(address(delegator), address(alltokensInMarket[0]));
    }

    // Verify price oracle setup
    function testPriceOracle() public {
        PriceOracle oracle = PriceOracle(comptroller.oracle());
        uint256 price = oracle.getUnderlyingPrice(CToken(address(delegator)));
        assertEq(price, 1e18, "USDT price should be set to 1 USD");
    }

    function testSupplyUSDT() public {
        // Use delegator address directly since we know it's the supported market
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(delegator);

        vm.startPrank(user);

        // Enter markets
        uint256[] memory errors = comptroller.enterMarkets(cTokens);
        assertEq(errors[0], 0, "Enter market failed");

        // Check initial balances
        uint256 cusdtBeforeBalance = delegator.balanceOf(user);
        uint256 usdtBeforeBalance = usdt.balanceOf(user);

        // Approve and mint
        usdt.approve(address(delegator), 100 ether);
        uint256 mintAmount = 1 ether;
        uint256 mintResult = delegator.mint(mintAmount);

        // Check final balances
        uint256 cusdtAfterBalance = delegator.balanceOf(user);
        uint256 usdtAfterBalance = usdt.balanceOf(user);

        // Assert the changes
        assertGt(cusdtAfterBalance, cusdtBeforeBalance, "cToken balance should increase");
        assertEq(usdtAfterBalance, usdtBeforeBalance - mintAmount, "USDT balance should decrease by mint amount");

        vm.stopPrank();
    }

    function testBorrowUsdt() public {
        // Arrange
        address[] memory markets = new address[](2);
        markets[0] = address(delegator); // USDT market
        markets[1] = address(delegatorusdc); // USDC market

        uint256 mintAmount = 10 ether;
        uint256 borrowAmount = 7 ether;

        vm.startPrank(user);

        // Enter both markets
        uint256[] memory errors = comptroller.enterMarkets(markets);
        assertEq(errors[0], 0, "Failed to enter USDT market");
        assertEq(errors[1], 0, "Failed to enter USDC market");

        // Supply USDT as collateral
        usdt.approve(address(delegator), mintAmount);
        uint256 mintResult = delegator.mint(mintAmount);
        assertEq(mintResult, 0, "Mint should succeed");

        // Attempt to borrow USDC
        uint256 borrowResult = delegatorusdc.borrow(borrowAmount);
        assertEq(borrowResult, 0, "Borrow should succeed");

        // Verify borrowed amount
        uint256 usdcBalance = usdc.balanceOf(user);
        assertEq(borrowAmount, usdcBalance, "USDC balance should match borrowed amount");

        vm.stopPrank();
    }
}
