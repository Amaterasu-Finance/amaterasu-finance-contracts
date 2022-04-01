// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/ERC20.sol";

contract USDC is ERC20("Test USDC", "USDC"), Ownable {

    constructor () public {
        _setupDecimals(6);
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}

contract USDT is ERC20("Test USDT", "USDT"), Ownable {

    constructor () public {
        _setupDecimals(6);
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}

contract NEAR is ERC20("Test NEAR", "NEAR"), Ownable {
    constructor () public {
        _setupDecimals(24);
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}

contract UST is ERC20("Test UST", "atUST"), Ownable {
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}

contract AURORA is ERC20("Test AURORA", "AURORA"), Ownable {
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}
