// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/math/SafeMath.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/utils/ReentrancyGuard.sol";

import "./IzaToken.sol";
import "../interfaces/IStake.sol";
import "../interfaces/IRewarder.sol";

contract MasterChef is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;         // How many LP tokens the user has provided.
        uint256 rewardDebt;     // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. Tokens to distribute per second.
        uint256 lastRewardTime;  // Last block number that Tokens distribution occurs.
        uint256 accTokenPerShare;   // Accumulated tokens per share, times 1e18. See below.
        uint16 depositFeeBP;      // Deposit fee in basis points
    }

    // The token!
    IzaToken public token;
    address public devAddress;
    address public feeAddress;
    address public marketingAddress;
    address public stakingAddress;

    uint256 public devRewardRate = 15;
    uint256 public marketingRewardRate = 5;

    // tokens created per second.
    uint256 public tokenPerSecond = 25000000000000000;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Rewarder for each pool
    IRewarder[] public rewarder;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block timestamp when mining starts.
    uint256 public startTime;
    // Max deposit fee
    uint256 public MAX_DEPOSIT_FEE = 600; // 6%

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event ClaimReward(address indexed user, uint256 indexed pid, bool stake);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event SetFeeAddress(address indexed user, address indexed newAddress);
    event SetDevAddress(address indexed user, address indexed newAddress);
    event SetMarketingAddress(address indexed user, address indexed newAddress);
    event SetStakingAddress(address indexed user, address indexed newAddress);
    event UpdateEmissionRate(address indexed user, uint256 tokenPerSecond);

    constructor(
        IzaToken _token,
        uint256 _startTime,
        address _devAddress,
        address _feeAddress,
        address _marketingAddress
    ) public {
        require(_devAddress != address(0), "Bad _devAddress");
        require(_feeAddress != address(0), "Bad _feeAddress");
        require(_marketingAddress != address(0), "Bad _marketingAddress");
        require(_startTime > block.timestamp, "Bad start time");

        token = _token;
        startTime = _startTime;
        devAddress = _devAddress;
        feeAddress = _feeAddress;
        marketingAddress = _marketingAddress;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    mapping(IERC20 => bool) public poolExistence;
    modifier nonDuplicated(IERC20 _lpToken) {
        require(poolExistence[_lpToken] == false, "nonDuplicated: duplicated");
        _;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        uint16 _depositFeeBP
    ) external onlyOwner nonDuplicated(_lpToken) {
        require(_depositFeeBP <= MAX_DEPOSIT_FEE, "add: invalid deposit fee basis points");
        uint256 lastRewardTime = block.timestamp > startTime ? block.timestamp : startTime;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolExistence[_lpToken] = true;
        rewarder.push(IRewarder(address(0)));
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardTime: lastRewardTime,
            accTokenPerShare: 0,
            depositFeeBP: _depositFeeBP
        }));
    }

    // Update the given pool's allocation point and deposit fee. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP) external onlyOwner {
        require(_depositFeeBP <= MAX_DEPOSIT_FEE, "set: invalid deposit fee basis points");
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
    }

    // Update the given pool's rewarder
    function setRewarder(uint256 _pid, IRewarder _rewarder) external onlyOwner {
        rewarder[_pid] = _rewarder;
    }

    // Return reward multiplier over the given _from to _to time.
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from);
    }

    // View function to see pending tokens on frontend.
    function pendingToken(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
            uint256 tokenReward = multiplier.mul(tokenPerSecond).mul(pool.allocPoint).div(totalAllocPoint);
            accTokenPerShare = accTokenPerShare.add(tokenReward.mul(1e18).div(lpSupply));
        }
        return user.amount.mul(accTokenPerShare).div(1e18).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
        uint256 tokenReward = multiplier.mul(tokenPerSecond).mul(pool.allocPoint).div(totalAllocPoint);
        token.mint(devAddress, tokenReward.mul(devRewardRate).div(100));
        token.mint(marketingAddress, tokenReward.mul(marketingRewardRate).div(100));
        token.mint(address(this), tokenReward);
        pool.accTokenPerShare = pool.accTokenPerShare.add(tokenReward.mul(1e18).div(lpSupply));
        pool.lastRewardTime = block.timestamp;
    }

    // Deposit LP tokens to MasterChef for allocation.
    function deposit(uint256 _pid, uint256 _amount, address _to) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_to];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accTokenPerShare).div(1e18).sub(user.rewardDebt);
            if (pending > 0) {
                safeTokenTransfer(_to, pending, false);
            }
        }
        if (_amount > 0) {
            // Accounting for tax tokens
            uint256 beforeDeposit = pool.lpToken.balanceOf(address(this));
            pool.lpToken.safeTransferFrom(msg.sender, address(this), _amount);
            uint256 afterDeposit = pool.lpToken.balanceOf(address(this));
            _amount = afterDeposit.sub(beforeDeposit);

            if (pool.depositFeeBP > 0) {
                uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);
                pool.lpToken.safeTransfer(feeAddress, depositFee);
                user.amount = user.amount.add(_amount).sub(depositFee);
            } else {
                user.amount = user.amount.add(_amount);
            }
        }
        // Interactions
        IRewarder _rewarder = rewarder[_pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onReward(_pid, _to, _to, 0, user.amount);
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e18);
        emit Deposit(_to, _pid, _amount);
    }

    // Claim Rewards
    function claimReward(uint256 _pid, bool _stake) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accTokenPerShare).div(1e18).sub(user.rewardDebt);
            if (pending > 0) {
                safeTokenTransfer(msg.sender, pending, _stake);
            }
            IRewarder _rewarder = rewarder[_pid];
            if (address(_rewarder) != address(0)) {
                _rewarder.onReward(_pid, msg.sender, msg.sender, pending, user.amount);
            }
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e18);
        emit ClaimReward(msg.sender, _pid, _stake);
    }

    // Deposit for staking
    // Doesn't return the reward but instead adds it to the amount staked
    function depositStaking(uint256 _amount) external {
        require(msg.sender == stakingAddress, 'not staking address');
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        updatePool(0);
        uint256 pending = 0;
        if (user.amount > 0) {
            pending = user.amount.mul(pool.accTokenPerShare).div(1e18).sub(user.rewardDebt);
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(_msgSender(), address(this), _amount);
        }
        if (_amount + pending > 0) {
            // Just add pending to amount instead of returning rewards
            user.amount = user.amount.add(_amount + pending);
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e18);
        emit Deposit(msg.sender, 0, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accTokenPerShare).div(1e18).sub(user.rewardDebt);
        if (pending > 0) {
            safeTokenTransfer(msg.sender, pending, false);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        // Interactions
        IRewarder _rewarder = rewarder[_pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onReward(_pid, msg.sender, msg.sender, 0, user.amount);
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e18);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        IRewarder _rewarder = rewarder[_pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onReward(_pid, msg.sender, msg.sender, 0, 0);
        }
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe token transfer function, just in case if rounding error causes pool to not have enough Tokens.
    function safeTokenTransfer(address _to, uint256 _amount, bool _stake) internal {
        uint256 tokenBal = token.balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > tokenBal) {
            _amount = tokenBal;
        }
        if (_stake && stakingAddress != address(0)) {
            transferSuccess = true;
            IERC20(address(token)).safeIncreaseAllowance(stakingAddress, _amount);
            IStake(stakingAddress).enter(_amount, _to);
        } else {
            transferSuccess = token.transfer(_to, _amount);
        }
        require(transferSuccess, "safeTokenTransfer: Transfer failed");
    }

    // Update dev address by the previous dev.
    function setDevAddress(address _devAddress) external onlyOwner {
        devAddress = _devAddress;
        emit SetDevAddress(msg.sender, _devAddress);
    }

    function setFeeAddress(address _feeAddress) external onlyOwner {
        feeAddress = _feeAddress;
        emit SetFeeAddress(msg.sender, _feeAddress);
    }

    function setStakingAddress(address _stakingAddress) external onlyOwner {
        stakingAddress = _stakingAddress;
        emit SetStakingAddress(msg.sender, _stakingAddress);
    }

    function setMarketingAddress(address _marketingAddress) external onlyOwner {
        marketingAddress = _marketingAddress;
        emit SetMarketingAddress(msg.sender, _marketingAddress);
    }
    
    function updateEmissionRate(uint256 _tokenPerSecond) external onlyOwner {
        massUpdatePools();
        tokenPerSecond = _tokenPerSecond;
        emit UpdateEmissionRate(msg.sender, _tokenPerSecond);
    }

    // Only update before start of farm
    function updateStartTime(uint256 _startTime) external onlyOwner {
	    require(_startTime > block.timestamp, "Farm already started");
        startTime = _startTime;
    }
}
