// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IOpenSwapChef {
  function deposit ( uint256 _pid, uint256 _amount ) external;
  function emergencyWithdraw ( uint256 _pid ) external;
  function poolInfo ( uint256 ) external view returns ( address lpToken, uint256 allocPoint, uint256 lastRewardBlock, uint256 accSushiPerShare );
  function userInfo ( uint256, address ) external view returns ( uint256 amount, uint256 rewardDebt );
  function withdraw ( uint256 _pid, uint256 _amount ) external;
}