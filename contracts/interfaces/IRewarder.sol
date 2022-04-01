// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/IERC20.sol";

interface IRewarder {
    function onReward(
        uint256 pid,
        address user,
        address recipient,
        uint256 amount,
        uint256 newLpAmount
    ) external;

    function pendingTokens(
        uint256 pid,
        address user,
        uint256 amount
    ) external view returns (
        IERC20[] memory,
        uint256[] memory
    );
}
