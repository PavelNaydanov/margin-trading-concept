// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface ISimpleOrderBook {
   function buy(uint256 _id, uint256 _quantity) external;
}