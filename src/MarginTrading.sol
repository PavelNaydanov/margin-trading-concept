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

    event PositionOpened(uint256 amount);
    event PositionClosed(uint256 amount);

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

    function openPosition(uint256 orderId, uint256 amount, uint256 leverage) external onlyOwner {
        uint256 loanAmount = amount * leverage;

        liquidityPool.borrow(loanAmount);

        // Метод buy всего лишь закрывает уже существующий ордер
        // Если это ордер на покупку токена B(в обмен отдаем токен А), то это long position
        // Если это ордер на продажу токена A(в обмен получаем токен B), то это short position
        tokenA.safeApprove(address(orderBook), loanAmount);
        orderBook.buy(orderId, loanAmount);

        emit PositionOpened(loanAmount);
    }

    function closePosition(uint256 orderId) external onlyOwner {
        tokenB.approve(address(orderBook), tokenB.balanceOf(address(this)));
        orderBook.buy(orderId, tokenB.balanceOf(address(this)));

        uint256 debt = liquidityPool.getDebt(address(this));

        tokenA.approve(address(liquidityPool), debt);
        liquidityPool.repay(debt);

        uint256 profit = tokenA.balanceOf(address(this));
        tokenA.safeTransfer(owner(), profit);

        emit PositionClosed(profit);
    }
}