// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

import "./interfaces/ILiquidityPool.sol";
import "./interfaces/ISimpleOrderBook.sol";

contract MarginTrading is Ownable {
    using SafeERC20 for IERC20;

    ILiquidityPool liquidityPool;
    ISimpleOrderBook orderBook;

    IERC20 tokenA;
    IERC20 tokenB;

    uint256 public longDebtA;
    uint256 public longBalanceB;

    uint256 public shortDebtA;
    uint256 public shortBalanceB;

    error MarginTrading__InsufficientAmountForClosePosition();

    event LongOpened();
    event LongClosed();
    event ShortOpened();
    event ShortClosed();

    constructor(
        address _liquidityPool,
        address _orderBook,
        address _tokenA,
        address _tokenB
    ) {
        liquidityPool = ILiquidityPool(_liquidityPool);
        orderBook = ISimpleOrderBook(_orderBook);

        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function openLong(uint256 amountBToBuy, uint256 leverage) external onlyOwner {
        uint256 amountAToSell = orderBook.calcAmountToSell(address(tokenA), address(tokenB), amountBToBuy * leverage);

        liquidityPool.borrow(amountAToSell);

        longDebtA += amountAToSell;
        longBalanceB += amountBToBuy;

        tokenA.safeApprove(address(orderBook), amountAToSell);
        orderBook.buy(address(tokenA), address(tokenB), amountBToBuy);

        emit LongOpened();
    }

    function closeLong() external onlyOwner {
        tokenB.safeApprove(address(orderBook), longBalanceB);
        uint256 balanceA = orderBook.sell(address(tokenB), address(tokenA), longBalanceB);

        if (balanceA < longDebtA) {
            revert MarginTrading__InsufficientAmountForClosePosition();
        }

        tokenA.safeApprove(address(liquidityPool), longDebtA);
        liquidityPool.repay(longDebtA);

        longDebtA = 0;
        longBalanceB = 0;

        uint256 freeTokenA = tokenA.balanceOf(address(this));
        tokenA.safeTransfer(owner(), freeTokenA);

        emit LongClosed();
    }

    function openShort(uint256 amountAToSell, uint leverage) external {
        liquidityPool.borrow(amountAToSell * leverage);

        shortDebtA += amountAToSell * leverage;

        tokenA.safeApprove(address(orderBook), amountAToSell * leverage);
        shortBalanceB += orderBook.sell(address(tokenA), address(tokenB), amountAToSell * leverage);

        emit ShortOpened();
    }

    function closeShort() external {
        tokenB.safeApprove(address(orderBook), shortBalanceB);
        uint256 balanceA = orderBook.buy(address(tokenB), address(tokenA), shortDebtA);

        if (balanceA < longDebtA) {
            revert MarginTrading__InsufficientAmountForClosePosition();
        }

        tokenA.safeApprove(address(liquidityPool), shortDebtA);
        liquidityPool.repay(shortDebtA);

        shortDebtA = 0;
        shortBalanceB = 0;

        uint256 freeTokenB = tokenB.balanceOf(address(this));
        tokenB.safeTransfer(owner(), freeTokenB);

        emit ShortClosed();
    }
}