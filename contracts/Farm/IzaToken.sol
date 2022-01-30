// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/ERC20.sol";

contract IzaToken is ERC20("Izanagi Token", "IZA"), Ownable {
    
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}