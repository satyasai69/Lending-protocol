# Lending Protocol

A Compound-style lending protocol built with Solidity and Foundry, enabling users to supply assets and borrow against collateral.

## Features

- Supply and borrow multiple assets (USDT, USDC)
- Collateral management with configurable factors
- Dynamic interest rate models
- Protocol reserves for risk management
- Price oracle integration for accurate valuations
- Governance timelock for protocol upgrades

## Architecture

The protocol consists of several key components:

### Core Contracts

1. **Comptroller**: 
   - Manages markets and collateral factors
   - Tracks user positions
   - Handles liquidation thresholds
   - Controls protocol parameters

2. **CToken (CErc20)**:
   - Represents supplied assets (e.g., cUSDT, cUSDC)
   - Handles interest accrual
   - Manages token supply and borrows
   - Maintains protocol reserves

3. **PriceOracle**:
   - Provides asset prices
   - Used for collateral calculations
   - Ensures accurate liquidation thresholds

4. **Timelock**:
   - Handles governance actions
   - Manages protocol upgrades
   - Controls parameter changes

### Example Usage

```solidity
// 1. Supply USDT as collateral
IERC20(USDT).approve(cUSDT_address, amount);
CErc20Interface(cUSDT).mint(amount);

// 2. Enable asset as collateral
address[] memory markets = new address[](1);
markets[0] = cUSDT_address;
comptroller.enterMarkets(markets);

// 3. Borrow USDC
CErc20Interface(cUSDC).borrow(borrowAmount);

// 4. Repay borrowed USDC
IERC20(USDC).approve(cUSDC_address, repayAmount);
CErc20Interface(cUSDC).repayBorrow(repayAmount);

// 5. Withdraw supplied USDT
CErc20Interface(cUSDT).redeem(redeemTokens);
```

## Testing

The protocol includes comprehensive tests using Foundry. Here's an example test:

```solidity
contract ComptrollerTest is Test {
    function testSupplyAndBorrow() public {
        // Setup
        usdt.mint(user, 10 ether);
        vm.startPrank(user);
        
        // Supply USDT
        usdt.approve(address(delegator), 10 ether);
        delegator.mint(10 ether);
        
        // Enter market
        address[] memory markets = new address[](1);
        markets[0] = address(delegator);
        comptroller.enterMarkets(markets);
        
        // Borrow USDC
        uint256 borrowAmount = 5 ether;
        delegatorusdc.borrow(borrowAmount);
        
        // Verify borrow
        assertEq(
            CErc20Interface(address(delegatorusdc))
                .borrowBalanceStored(user),
            borrowAmount
        );
    }
}
```

## Setup

1. Install Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Clone the repository:
```bash
git clone <repository-url>
cd lending-protocol
```

3. Install dependencies:
```bash
forge install
```

4. Run tests:
```bash
forge test
```

## Key Protocol Parameters

- **Collateral Factor**: Determines how much you can borrow against your collateral
- **Reserve Factor**: Portion of interest that goes to protocol reserves
- **Interest Rate Model**: Dynamic rates based on utilization
- **Liquidation Threshold**: When accounts become eligible for liquidation
- **Close Factor**: Maximum portion that can be liquidated at once

## Security Considerations

- All functions that modify state have access control
- Reentrancy protection on critical functions
- Price oracle manipulation protection
- Proper decimal handling for token math
- Protocol reserves for risk management

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

MIT
