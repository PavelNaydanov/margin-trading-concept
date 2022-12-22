// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface ILiquidityPool {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function borrow(uint256 amount) external;
    function repay(uint256 amount) external;
    function getDebt(address borrower) external view returns (uint256);
}