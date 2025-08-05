// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./IPrimisBase.sol";

interface IPrimisStrategy is IPrimisBase {
    function deposit(PrmRequest memory) external returns (uint256);

    function withdrawStEth(PrmRequest memory) external returns (uint256);

    function withdrawRequest(PrmRequest memory) external;

    function checkDeposit(address, uint256) external view returns (bool);

    function hasRequest() external view returns (bool);
}
