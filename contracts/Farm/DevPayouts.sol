// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/math/SafeMath.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol";


contract DevPayouts is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Allocation of each user
    mapping(address => uint256) public userInfo;

    address[] public payees;
    mapping(address => bool) public payeeExists;

    // Total allocation points. Must be the sum of all user allocation points
    uint256 public totalAllocPoint;

    event DistributeRewards(address indexed user, uint256 amount);

    constructor() public {}

    // Add a new user. Can only be called by the owner.
    function updateUser(address _user, uint256 _allocPoint) external onlyOwner {
        require(_user != address(0), "Bad address");
        uint256 currentAllocPoint = userInfo[_user];
        totalAllocPoint = totalAllocPoint.add(_allocPoint).sub(currentAllocPoint);
        userInfo[_user] = _allocPoint;
        if (!payeeExists[_user]) {
            payees.push(_user);
            payeeExists[_user] = true;
        }
    }

    // Distribute Rewards
    function distributeReward(address _token) public {
        require(payees.length > 0, "Nobody to pay!");
        require(totalAllocPoint > 0, "Nobody to pay!");

        uint256 amount = IERC20(_token).balanceOf(address(this));
        require(amount > 0, "No tokens to give out");

        for (uint256 idx; idx < payees.length; ++idx) {
            address _user = payees[idx];
            uint256 userAlloc = userInfo[_user];
            if (userAlloc > 0) {
                safeTokenTransfer(_token, _user, amount.mul(userAlloc).div(totalAllocPoint));
            }
        }
        emit DistributeRewards(msg.sender, amount);
    }

    // Safe token transfer function, just in case if rounding error causes pool to not have enough Tokens.
    function safeTokenTransfer(address _token, address _to, uint256 _amount) internal {
        uint256 tokenBal = IERC20(_token).balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > tokenBal) {
            _amount = tokenBal;
        }
        transferSuccess = IERC20(_token).transfer(_to, _amount);
        require(transferSuccess, "safeTokenTransfer: Transfer failed");
    }

    function balanceOf(address tokenAddress) external view returns (uint256) {
       return IERC20(tokenAddress).balanceOf(address(this));
    }

    function recoverToken(address tokenAddress) public onlyOwner {
        IERC20(tokenAddress).transfer(owner(), IERC20(tokenAddress).balanceOf(address(this)));
    }
}
