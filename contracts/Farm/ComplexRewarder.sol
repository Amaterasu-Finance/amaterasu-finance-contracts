// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/math/SafeMath.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol";
import "../interfaces/IRewarder.sol";
import "../interfaces/IMasterChef.sol";


/**
 * This is a sample contract to be used in the MasterChef contract for partners to reward
 * stakers with their native token alongside native.
 *
 * It assumes the project already has an existing MasterChef-style farm contract.
 * The contract then transfers the reward token to the user on each call to
 * onReward().
 *
 */
contract ComplexRewarder is IRewarder, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public immutable rewardToken;
    IERC20 public immutable lpToken;
    IMasterChef public immutable masterchef;

    /// @notice Info of each masterchef user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of native entitled to the user.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    /// @notice Info of each masterchef poolInfo.
    /// `accTokenPerShare` Amount of rewardTokens each LP token is worth.
    /// `lastRewardTime` The last time rewards were rewarded to the poolInfo.
    struct PoolInfo {
        uint256 accTokenPerShare;
        uint256 lastRewardTime;
    }

    /// @notice Info of the poolInfo.
    PoolInfo public poolInfo;
    /// @notice Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;

    uint256 public tokenPerSecond;
    uint256 private constant ACC_TOKEN_PRECISION = 1e12;

    event OnReward(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event AllocPointUpdated(uint256 oldAllocPoint, uint256 newAllocPoint);

    modifier onlyMasterchef() {
        require(msg.sender == address(masterchef), "onlyMasterchef: only MasterChef can call this function");
        _;
    }

    constructor(
        IERC20 _rewardToken,
        IERC20 _lpToken,
        uint256 _tokenPerSecond,
        IMasterChef _masterchef
    ) public {
        rewardToken = _rewardToken;
        lpToken = _lpToken;
        tokenPerSecond = _tokenPerSecond;
        masterchef = _masterchef;
        poolInfo = PoolInfo({lastRewardTime: block.timestamp, accTokenPerShare: 0});
    }


    /// @notice Sets the distribution reward rate. This will also update the poolInfo.
    /// @param _tokenPerSecond The number of tokens to distribute per second
    function setRewardRate(uint256 _tokenPerSecond) external onlyOwner {
        updatePool();

        uint256 oldRate = tokenPerSecond;
        tokenPerSecond = _tokenPerSecond;

        emit RewardRateUpdated(oldRate, _tokenPerSecond);
    }

    // @notice Allows owner to reclaim/withdraw any tokens (including reward tokens) held by this contract
    /// @param token Token to reclaim, use 0x00 for Ethereum
    /// @param amount Amount of tokens to reclaim
    /// @param to Receiver of the tokens
    function reclaimTokens(address token, uint256 amount, address payable to) public onlyOwner {
        if (token == address(0)) {
            to.transfer(amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    /// @notice Update reward variables of the given poolInfo.
    /// @return pool Returns the pool that was updated.
    function updatePool() public returns (PoolInfo memory pool) {
        pool = poolInfo;

        if (block.timestamp > pool.lastRewardTime) {
            uint256 lpSupply = lpToken.balanceOf(address(masterchef));

            if (lpSupply > 0) {
                uint256 secondsDiff = block.timestamp.sub(pool.lastRewardTime);
                uint256 tokenReward = secondsDiff.mul(tokenPerSecond);
                pool.accTokenPerShare = pool.accTokenPerShare.add((tokenReward.mul(ACC_TOKEN_PRECISION) / lpSupply));
            }

            pool.lastRewardTime = block.timestamp;
            poolInfo = pool;
        }
    }

    /// @notice Function called by MasterChef whenever staker claims harvest.
    /// Allows staker to also receive a 2nd reward token.
    /// @param _user Address of user
    /// @param _lpAmount Number of LP tokens the user has
    function onReward(
        uint256,
        address _user,
        address,
        uint256,
        uint256 _lpAmount
    ) external override onlyMasterchef {
        updatePool();
        PoolInfo memory pool = poolInfo;
        UserInfo storage user = userInfo[_user];
        uint256 pendingBal;
        // if user had deposited
        if (user.amount > 0) {
            pendingBal = (user.amount.mul(pool.accTokenPerShare) / ACC_TOKEN_PRECISION).sub(user.rewardDebt);
            uint256 rewardBal = rewardToken.balanceOf(address(this));
            if (pendingBal > rewardBal) {
                rewardToken.safeTransfer(_user, rewardBal);
            } else {
                rewardToken.safeTransfer(_user, pendingBal);
            }
        }

        user.amount = _lpAmount;
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare) / ACC_TOKEN_PRECISION;

        emit OnReward(_user, pendingBal);
    }

    /// @notice View function to see pending tokens
    /// @param _user Address of user.
    function pendingTokens(
        uint256,
        address _user,
        uint256
    ) external view override returns (IERC20[] memory rewardTokens, uint256[] memory rewardAmounts) {
        IERC20[] memory _rewardTokens = new IERC20[](1);
        _rewardTokens[0] = (rewardToken);
        uint256[] memory _rewardAmounts = new uint256[](1);

        PoolInfo memory pool = poolInfo;
        UserInfo storage user = userInfo[_user];

        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 lpSupply = lpToken.balanceOf(address(masterchef));

        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint256 secondsDiff = block.timestamp.sub(pool.lastRewardTime);
            uint256 tokenReward = secondsDiff.mul(tokenPerSecond);
            accTokenPerShare = accTokenPerShare.add(tokenReward.mul(ACC_TOKEN_PRECISION) / lpSupply);
        }

        _rewardAmounts[0] = (user.amount.mul(accTokenPerShare) / ACC_TOKEN_PRECISION).sub(user.rewardDebt);
        return (_rewardTokens, _rewardAmounts);
    }
}
