// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/ERC20.sol";

contract IzaToken is ERC20("Izanagi Token", "IZA"), Ownable {

    // Max transfer amount rate in basis points. Default is 100% of total
    // supply, and it can't be less than 0.5% of the supply.
    uint16 public maxTransferAmountRate = 10000;

    // Addresses that are excluded from anti-whale checking.
    mapping(address => bool) private _excludedFromAntiWhale;
    mapping(address => bool) public authorized;

    event MaxTransferAmountRateUpdated(uint256 previousRate, uint256 newRate);

    /**
     * @dev Ensures that the anti-whale rules are enforced.
     */
    modifier antiWhale(address sender, address recipient, uint256 amount) {
        if (maxTransferAmount() > 0) {
            if (
                _excludedFromAntiWhale[sender] == false
                && _excludedFromAntiWhale[recipient] == false
            ) {
                require(amount <= maxTransferAmount(), "antiWhale: Transfer amount exceeds the maxTransferAmount");
            }
        }
        _;
    }

    /**
     * @dev Add authorized user for changing anti-whale params
     */
    modifier onlyAuthorized() {
        require(authorized[msg.sender] || owner() == msg.sender, "caller is not authorized");
        _;
    }

    constructor() public {
        _excludedFromAntiWhale[msg.sender] = true;
        _excludedFromAntiWhale[address(0)] = true;
        _excludedFromAntiWhale[address(this)] = true;
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override antiWhale(sender, recipient, amount) {
        super._transfer(sender, recipient, amount);
    }

    /**
     * @dev Calculates the max transfer amount.
     */
    function maxTransferAmount() public view returns (uint256) {
        return totalSupply().mul(maxTransferAmountRate).div(10000);
    }

    /**
    * @dev Update the max transfer amount rate.
     */
    function updateMaxTransferAmountRate(uint16 _maxTransferAmountRate) public onlyAuthorized {
        require(_maxTransferAmountRate <= 10000, "updateMaxTransferAmountRate: Max transfer amount rate must not exceed the maximum rate.");
        require(_maxTransferAmountRate >= 50, "updateMaxTransferAmountRate: Max transfer amount rate must be more than 0.005.");
        emit MaxTransferAmountRateUpdated(maxTransferAmountRate, _maxTransferAmountRate);
        maxTransferAmountRate = _maxTransferAmountRate;
    }

    /**
     * @dev Sets an address as excluded or not from the anti-whale checking.
     */
    function setExcludedFromAntiWhale(address _account, bool _excluded) public onlyAuthorized {
        _excludedFromAntiWhale[_account] = _excluded;
    }

    function addAuthorized(address _toAdd) public onlyAuthorized {
        authorized[_toAdd] = true;
    }

    function removeAuthorized(address _toRemove) public onlyAuthorized {
        require(_toRemove != msg.sender);
        authorized[_toRemove] = false;
    }

}