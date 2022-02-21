// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/ERC20.sol";

contract tUSDC is ERC20("Test USDC", "tUSDC"), Ownable {

    constructor () public {
        _setupDecimals(18);
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}

contract tETH is ERC20("Test ETH", "tETH"), Ownable {
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}

contract tFTM is ERC20("Test FTM", "tFTM"), Ownable {
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}

contract tMIM is ERC20("Test MIM", "tMIM"), Ownable {
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}

contract tONE is ERC20("Test ONE", "tONE"), Ownable {
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}
