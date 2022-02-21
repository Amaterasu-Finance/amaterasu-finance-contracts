// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/ERC20.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/utils/Pausable.sol";


import "../interfaces/IMasterChef.sol";

contract xToken is Ownable, Pausable, ERC20 {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    struct UserInfo {
        uint256 lastDepositedTime; // keeps track of deposited time for potential penalty
        uint256 tokensAtLastUserAction; // keeps track of tokens deposited at the last user action
        uint256 lastUserActionTime; // keeps track of the last user action time
    }

    IERC20 public immutable token; // token

    uint256 public lastEarnBlock = block.number;
    IMasterChef public immutable masterchef;

    mapping(address => UserInfo) public userInfo;

    uint256 public lastHarvestedTime;
    address public admin;

    uint256 public constant MAX_CALL_FEE = 100; // 1%
    uint256 public constant MAX_WITHDRAW_FEE = 100; // 1%
    uint256 public constant MAX_WITHDRAW_FEE_PERIOD = 72 hours; // 3 days

    uint256 public callFee = 50; // 0.50% on rewards
    uint256 public withdrawFee = 100; // 1%
    uint256 public withdrawFeePeriod = 6 hours;

    event Deposit(address indexed sender, uint256 amount, uint256 shares, uint256 lastDepositedTime);
    event Withdraw(address indexed sender, uint256 amount, uint256 shares);
    event Harvest(address indexed sender, uint256 callFee);
    event Pause();
    event Unpause();

    /**
     * @notice Constructor
     * @param _name: ERC20 Token Name
     * @param _symbol: ERC20 Token Symbol
     * @param _token: token contract
     * @param _masterchef: Masterchef contract
     * @param _admin: address of the admin
     */
    constructor(
        string memory _name,
        string memory _symbol,
        IERC20 _token,
        IMasterChef _masterchef,
        address _admin
    ) public ERC20(_name, _symbol) {
        token = _token;
        masterchef = _masterchef;
        admin = _admin;

        // Infinite approve
        IERC20(_token).safeApprove(address(_masterchef), uint256(-1));
    }

    /**
     * @notice Checks if the msg.sender is the admin address
     */
    modifier onlyAdmin() {
        require(msg.sender == admin, "admin: wut?");
        _;
    }

    /**
     * @notice Checks if the msg.sender is a contract or a proxy
     */
    modifier notContract() {
        require(!_isContract(msg.sender), "contract not allowed");
        require(msg.sender == tx.origin, "proxy contract not allowed");
        _;
    }

    /**
     * @notice Deposits funds into the Vault and mints xToken
     * @dev Only possible when contract not paused.
     * @param _amount: number of tokens to deposit (in TOKENS)
     */
    function enter(uint256 _amount, address _to) external whenNotPaused {
        require(_amount > 0, "Nothing to deposit");

        uint256 pool = balanceOfThis();
        token.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 currentShares = 0;
        uint256 totalShares = totalSupply();
        if (totalShares != 0) {
            // Calculate and mint the amount of xGovernanceToken the GovernanceToken is worth.
            // The ratio will change overtime, as xGovernanceToken is burned/minted and GovernanceToken deposited + gained from fees / withdrawn.
            currentShares = (_amount.mul(totalShares)).div(pool);
        } else {
            // If no xGovernanceToken exists, mint it 1:1 to the amount put in
            currentShares = _amount;
        }
        UserInfo storage user = userInfo[_to];

        _mint(_to, currentShares);
        totalShares = totalSupply();
        user.lastDepositedTime = block.timestamp;

        user.tokensAtLastUserAction = balanceOf(_to).mul(balanceOfThis()).div(totalShares);
        user.lastUserActionTime = block.timestamp;

        _earn();

        emit Deposit(_to, _amount, currentShares, block.timestamp);
    }

    /**
     * @notice Reinvests tokens into Masterchef
     * @dev Only possible when contract not paused.
     */
    function earn() external notContract whenNotPaused {
        uint256 bal = available();

        uint256 currentCallFee = bal.mul(callFee).div(10000);
        if (currentCallFee > 0) {
            token.safeTransfer(msg.sender, currentCallFee);
        }

        _earn();

        lastHarvestedTime = block.timestamp;

        emit Harvest(msg.sender, currentCallFee);
    }


    /**
     * @notice Sets admin address
     * @dev Only callable by the contract owner.
     */
    function setAdmin(address _admin) external onlyOwner {
        require(_admin != address(0), "Cannot be zero address");
        admin = _admin;
    }

    /**
     * @notice Sets call fee
     * @dev Only callable by the contract admin.
     */
    function setCallFee(uint256 _callFee) external onlyAdmin {
        require(_callFee <= MAX_CALL_FEE, "callFee cannot be more than MAX_CALL_FEE");
        callFee = _callFee;
    }

    /**
     * @notice Sets withdraw fee
     * @dev Only callable by the contract admin.
     */
    function setWithdrawFee(uint256 _withdrawFee) external onlyAdmin {
        require(_withdrawFee <= MAX_WITHDRAW_FEE, "withdrawFee cannot be more than MAX_WITHDRAW_FEE");
        withdrawFee = _withdrawFee;
    }

    /**
     * @notice Sets withdraw fee period
     * @dev Only callable by the contract admin.
     */
    function setWithdrawFeePeriod(uint256 _withdrawFeePeriod) external onlyAdmin {
        require(
            _withdrawFeePeriod <= MAX_WITHDRAW_FEE_PERIOD,
            "withdrawFeePeriod cannot be more than MAX_WITHDRAW_FEE_PERIOD"
        );
        withdrawFeePeriod = _withdrawFeePeriod;
    }

    /**
     * @notice Withdraws from Masterchef to Vault without caring about rewards.
     * @dev EMERGENCY ONLY. Only callable by the contract admin.
     */
    function emergencyWithdraw() external onlyAdmin {
        IMasterChef(masterchef).emergencyWithdraw(0);
    }

    /**
     * @notice Withdraw unexpected tokens sent to the Vault
     */
    function inCaseTokensGetStuck(address _token) external onlyAdmin {
        require(_token != address(token), "Token cannot be same as deposit token");

        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Triggers stopped state
     * @dev Only possible when contract not paused.
     */
    function pause() external onlyAdmin whenNotPaused {
        _pause();
        emit Pause();
    }

    /**
     * @notice Returns to normal state
     * @dev Only possible when contract is paused.
     */
    function unpause() external onlyAdmin whenPaused {
        _unpause();
        emit Unpause();
    }

    /**
     * @notice Calculates the total pending rewards that can be restaked
     * @return Returns total pending rewards
     */
    function calculateTotalPendingRewards() public view returns (uint256) {
        uint256 amount = IMasterChef(masterchef).pendingToken(0, address(this));
        amount = amount.add(available());
        return amount;
    }


    /**
     * @notice Calculates the price per share
     */
    function getPricePerFullShare() public view returns (uint256) {
        uint256 totalShares = totalSupply();
        return totalShares == 0 ? 1e18 : balanceOfThis().mul(1e18).div(totalShares);
    }

    /**
     * @notice Calculates Tokens for user
     */
    function wantLockedTotal(address _user) external view returns (uint256) {
        return balanceOf(_user).mul(getPricePerFullShare()).div(1e18);
    }

    /**
     * @notice Burns xToken for Token and withdraws funds from the Token Vault
     * @param _shares: Number of xToken to burn
     */
    function leave(uint256 _shares) public notContract {
        require(_shares > 0, "Nothing to withdraw");
        UserInfo storage user = userInfo[msg.sender];
        _earn();
        uint256 userShares = balanceOf(msg.sender);
        if (_shares > userShares) {
            _shares = userShares;
        }

        uint256 totalShares = totalSupply();
        uint256 currentAmount = (balanceOfThis().mul(_shares)).div(totalShares);
        // user.shares = user.shares.sub(_shares);
        totalShares = totalShares.sub(_shares);

        uint256 bal = available();
        if (bal < currentAmount) {
            uint256 balWithdraw = currentAmount.sub(bal);
            IMasterChef(masterchef).withdraw(0, balWithdraw);
            uint256 balAfter = available();
            uint256 diff = balAfter.sub(bal);
            if (diff < balWithdraw) {
                currentAmount = bal.add(diff);
            }
        }

        if (block.timestamp < user.lastDepositedTime.add(withdrawFeePeriod)) {
            uint256 currentWithdrawFee = currentAmount.mul(withdrawFee).div(10000);
            // token.safeTransfer(treasury, currentWithdrawFee);
            // keep fee in contract for everyone else
            currentAmount = currentAmount.sub(currentWithdrawFee);
        }

        _burn(msg.sender, _shares);

        if (balanceOf(msg.sender) > 0) {
            user.tokensAtLastUserAction = balanceOf(msg.sender).mul(balanceOfThis()).div(totalShares);
        } else {
            user.tokensAtLastUserAction = 0;
        }

        user.lastUserActionTime = block.timestamp;
        token.safeTransfer(msg.sender, currentAmount);

        emit Withdraw(msg.sender, currentAmount, _shares);
    }

    /**
     * @notice Custom logic for how much the vault allows to be borrowed
     * @dev The contract puts 100% of the tokens to work.
     */
    function available() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /**
     * @notice Calculates the total underlying tokens
     * @dev It includes tokens held by the contract and held in Masterchef
     */
    function balanceOfThis() public view returns (uint256) {
        (uint256 amount, ) = IMasterChef(masterchef).userInfo(0, address(this));
        return amount.add(calculateTotalPendingRewards());
    }

    /**
     * @notice Deposits tokens into MasterChef to earn staking rewards
     */
    function _earn() internal {
        uint256 bal = available();
        IMasterChef(masterchef).depositStaking(bal);
        lastEarnBlock = block.number;
    }

    /**
     * @notice Checks if address is a contract
     * @dev It prevents contract from being targetted
     */
    function _isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
}