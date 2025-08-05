// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "./IPrimisBase.sol";

interface IPrimisTreasury is IPrimisBase {
    function depositTreasury(PrmRequest memory, uint256) external;

    function withdraw(PrmRequest memory, uint256) external ;

    function collect(address, uint256) external;

    function mintEndToUser(address, uint256) external;

    function stakeRebasingReward(address _asset) external returns (uint256 rebaseReward);

    function ETHDenomination(address _stEthAddress) external view returns (uint stETHPoolAmount, uint PrmSupply);
}
