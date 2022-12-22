// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

// 1. Я ничего не вставил в контракт про fee, предлагаю опустить это и сказать о физах, как о недостатке нашего решения в конце.
// 2. Я переделал модификаторы методов. Идея такая, что любой может стать поставщиком ликвидности и любой может занимать средства.
contract LiquidityPool {
    using SafeERC20 for IERC20;

    IERC20 token;
    uint256 totalDebt;

    mapping(address => uint256) liquidityProviders;
    mapping(address => uint256) borrowers;

    error LiquidityPool_CallerIsNotLiquidityProvider(address caller);
    error LiquidityPool_CallerIsNotBorrower(address caller);
    error LiquidityPool_InsufficientLiquidity();

    event LiquidityAdded(address liquidityProvider, uint256 amount);
    event LiquidityWithdrawn(address liquidityProvider, uint256 amount);
    event Borrowed(address borrower, uint256 amount);
    event Repaid(address borrower, uint256 amount);

    modifier onlyLiquidityProvider(address sender) {
        if (liquidityProviders[sender] == 0) {
            revert LiquidityPool_CallerIsNotLiquidityProvider(sender);
        }

        _;
    }

    modifier onlyBorrower(address sender) {
        if (borrowers[sender] == 0) {
            revert LiquidityPool_CallerIsNotBorrower(sender);
        }

        _;
    }

    constructor(address _token) {
        token = IERC20(_token);
    }

    function deposit(uint256 amount) external {
        liquidityProviders[msg.sender] = amount;

        token.safeTransferFrom(msg.sender, address(this), amount);

        emit LiquidityAdded(msg.sender, amount);
    }

    function withdraw(uint256 amount) external onlyLiquidityProvider(msg.sender) {
        if (liquidityProviders[msg.sender] > amount) {
            amount = liquidityProviders[msg.sender];
        }

        token.safeTransfer(msg.sender, amount);

        emit LiquidityWithdrawn(msg.sender, amount);
    }

    // Этот метод предлагаю переименовать с takeLeverage на borrow. Так вроде и по контексту больше подходит и по смыслу.
    // Еще я убрал аргумент leverage предлагаю, чтобы пул занимался только выдачей займов и закрытием и ничего не знал о плечах.
    // Сумма с плечом будет рассчитываться в контракте Margin trading
    function borrow(uint256 amount) external {
        if (amount > token.balanceOf(address(this))) {
            revert LiquidityPool_InsufficientLiquidity();
        }

        totalDebt += amount;
        borrowers[msg.sender] = amount;

        token.safeTransfer(msg.sender, amount);

        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external onlyBorrower(msg.sender) {
        totalDebt -= amount;

        token.safeTransferFrom(msg.sender, address(this), amount);

        emit Repaid(msg.sender, amount);
    }

    function getDebt(address borrower) external view returns (uint256) {
        return borrowers[borrower];
    }
}