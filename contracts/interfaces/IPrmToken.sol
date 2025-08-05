// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title IPrmToken interface
 * @notice Interface for the PrmToken contract
 */
interface IPrmToken {
    function mint(address to, uint256 amount) external;
    function distributeRefractionFees() external;
}
