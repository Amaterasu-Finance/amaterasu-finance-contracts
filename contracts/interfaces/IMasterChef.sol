// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IMasterChef {
    function deposit ( uint256 _pid, uint256 _amount, address _to, bool _stake ) external;
    function emergencyWithdraw ( uint256 _pid ) external;
    function pendingToken ( uint256 _pid, address _user ) external view returns ( uint256 );
    function userInfo ( uint256, address ) external view returns ( uint256 amount, uint256 rewardDebt );
    function withdraw ( uint256 _pid, uint256 _amount ) external;
}