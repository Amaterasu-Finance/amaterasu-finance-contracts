// SPDX-License-Identifier: MIT

// P1 - P3: OK
pragma solidity 0.6.12;

import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/math/SafeMath.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol";

import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2ERC20.sol";
import "../interfaces/IUniswapV2Router02.sol";

// This contract handles "serving up" rewards for xGovernanceToken holders
// by trading tokens collected from fees for GovernanceToken.

contract SunMaker is Ownable  {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable den;
    address private immutable govToken;
    address private immutable weth;
    IUniswapV2Factory public immutable factory;

    // V1 - V5: OK
    mapping(address => address) internal _bridges;
    mapping(address => bool) public operators;

    // E1: OK
    event LogBridgeSet(address indexed token, address indexed bridge);
    event OperatorUpdated(address indexed operator, bool indexed status);
    event StringFailure(string stringFailure);
    event BytesFailure(bytes bytesFailure);
    // E1: OK
    event LogConvert(
        address indexed server,
        address indexed token0,
        address indexed token1,
        uint256 amount0,
        uint256 amount1,
        uint256 amountGovToken
    );

    constructor(
        address _factory,
        address _den,
        address _govToken,
        address _weth
    ) public {
        factory = IUniswapV2Factory(_factory);
        den = _den;
        govToken = _govToken;
        weth = _weth;
        operators[msg.sender] = true;
    }

    // F1 - F10: OK
    // C1 - C24: OK
    function bridgeFor(address token) public view returns (address bridge) {
        bridge = _bridges[token];
        if (bridge == address(0)) {
            bridge = weth;
        }
    }

    // F1 - F10: OK
    // C1 - C24: OK
    function setBridge(address token, address bridge) external onlyOperator {
        // Checks
        require(
            token != govToken && token != weth && token != bridge,
            "SunMaker: Invalid bridge"
        );

        // Effects
        _bridges[token] = bridge;
        emit LogBridgeSet(token, bridge);
    }

    // M1 - M5: OK
    // C1 - C24: OK
    // C6: It's not a fool proof solution, but it prevents flash loans, so here it's ok to use tx.origin
    modifier onlyEOA() {
        // Try to make flash-loan exploit harder to do by only allowing externally owned addresses.
        require(msg.sender == tx.origin, "SunMaker: must use EOA");
        _;
    }

    modifier onlyOperator {
        require(operators[msg.sender], "Operator: caller is not the operator");
        _;
    }

    function burnLpToken(address lpTokenAddress) external onlyOperator {
        _burnLpToken(lpTokenAddress);
    }

    function burnMultipleLpTokens(address[] calldata lpTokens) external onlyOperator {
        uint256 len = lpTokens.length;
        for (uint256 i = 0; i < len; i++) {
            _burnLpToken(lpTokens[i]);
        }
    }

    function _burnLpToken(address lpTokenAddress) internal {
        IUniswapV2Pair lp = IUniswapV2Pair(lpTokenAddress);
        uint256 balance = lp.balanceOf(address(this));
        require(balance > 0, "SunMaker: Lp Balance is 0");
        IUniswapV2Router02(lp.router()).removeLiquidity(
            lp.token0(),
            lp.token1(),
            balance,
            0,
            0,
            address(this),
            block.timestamp
        );
    }

    function convertToken(address token) external onlyOperator {
        _convertToken(token);
    }

    /*
    function convertMultipleTokens(address[] calldata tokens) external onlyOperator {
        uint256 len = tokens.length;
        for (uint256 i = 0; i < len; i++) {
           try _convertToken(tokens[i]) {
               govToken;
           } catch Error(string memory _err) {
               // This may occur if there is an overflow with the two numbers and the `AddNumbers` contract explicitly fails with a `revert()`
               emit StringFailure(_err);
           } catch (bytes memory _err) {
               emit BytesFailure(_err);
           }
        }
    } */

    function _convertToken(address token) internal {
        // Swaps token for GovToken and sends to xGovToken
        uint256 amount0 = IERC20(token).balanceOf(address(this));
        uint256 amount1 = IERC20(govToken).balanceOf(address(this));

        emit LogConvert(
            msg.sender,
            token,
            govToken,
            amount0,
            amount1,
            _convertStep(token, govToken, amount0, amount1)
        );
    }

    // F1 - F10: OK
    // F3: _convert is separate to save gas by only checking the 'onlyEOA' modifier once in case of convertMultiple
    // F6: There is an exploit to add lots of GovernanceTokens, run convert, then remove the GovernanceTokens again.
    //     As the size of the Den has grown, this requires large amounts of funds and isn't super profitable anymore
    //     The onlyEOA modifier prevents this being done with a flash loan.
    // C1 - C24: OK
    function convert(address token0, address token1) external onlyEOA() {
        _convert(token0, token1);
    }

    // F1 - F10: OK, see convert
    // C1 - C24: OK
    // C3: Loop is under control of the caller
    function convertMultiple(
        address[] calldata token0,
        address[] calldata token1
    ) external onlyEOA() {
        // TODO: This can be optimized a fair bit, but this is safer and simpler for now
        uint256 len = token0.length;
        for (uint256 i = 0; i < len; i++) {
            _convert(token0[i], token1[i]);
        }
    }

    // F1 - F10: OK
    // C1- C24: OK
    function _convert(address token0, address token1) internal {
        // Interactions
        // S1 - S4: OK
        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(token0, token1));
        require(address(pair) != address(0), "SunMaker: Invalid pair");
        // balanceOf: S1 - S4: OK
        // transfer: X1 - X5: OK
        IERC20(address(pair)).safeTransfer(
            address(pair),
            pair.balanceOf(address(this))
        );
        // X1 - X5: OK
        pair.burn(address(this));
        // if (token0 != pair.token0()) {
        //     (amount0, amount1) = (amount1, amount0);
        // }
        uint256 amount0 = IERC20(token0).balanceOf(address(this));
        uint256 amount1 = IERC20(token1).balanceOf(address(this));
        emit LogConvert(
            msg.sender,
            token0,
            token1,
            amount0,
            amount1,
            _convertStep(token0, token1, amount0, amount1)
        );
    }

    // F1 - F10: OK
    // C1 - C24: OK
    // All safeTransfer, _swap, _toGovToken, _convertStep: X1 - X5: OK
    function _convertStep(
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) internal returns (uint256 govTokenOut) {
        // Interactions
        if (token0 == token1) {
            uint256 amount = amount0.add(amount1);
            if (token0 == govToken) {
                IERC20(govToken).safeTransfer(den, amount);
                govTokenOut = amount;
            } else if (token0 == weth) {
                govTokenOut = _toGovToken(weth, amount);
            } else {
                address bridge = bridgeFor(token0);
                amount = _swap(token0, bridge, amount, address(this));
                govTokenOut = _convertStep(bridge, bridge, amount, 0);
            }
        } else if (token0 == govToken) {
            // eg. GovToken - ETH
            IERC20(govToken).safeTransfer(den, amount0);
            govTokenOut = _toGovToken(token1, amount1).add(amount0);
        } else if (token1 == govToken) {
            // eg. USDT - GovToken
            IERC20(govToken).safeTransfer(den, amount1);
            govTokenOut = _toGovToken(token0, amount0).add(amount1);
        } else if (token0 == weth) {
            // eg. ETH - USDC
            govTokenOut = _toGovToken(
                weth,
                _swap(token1, weth, amount1, address(this)).add(amount0)
            );
        } else if (token1 == weth) {
            // eg. USDT - ETH
            govTokenOut = _toGovToken(
                weth,
                _swap(token0, weth, amount0, address(this)).add(amount1)
            );
        } else {
            // eg. MIC - USDT
            address bridge0 = bridgeFor(token0);
            address bridge1 = bridgeFor(token1);
            if (bridge0 == token1) {
                // eg. MIC - USDT - and bridgeFor(MIC) = USDT
                govTokenOut = _convertStep(
                    bridge0,
                    token1,
                    _swap(token0, bridge0, amount0, address(this)),
                    amount1
                );
            } else if (bridge1 == token0) {
                // eg. WBTC - DSD - and bridgeFor(DSD) = WBTC
                govTokenOut = _convertStep(
                    token0,
                    bridge1,
                    amount0,
                    _swap(token1, bridge1, amount1, address(this))
                );
            } else {
                govTokenOut = _convertStep(
                    bridge0,
                    bridge1, // eg. USDT - DSD - and bridgeFor(DSD) = WBTC
                    _swap(token0, bridge0, amount0, address(this)),
                    _swap(token1, bridge1, amount1, address(this))
                );
            }
        }
    }

    // F1 - F10: OK
    // C1 - C24: OK
    // All safeTransfer, swap: X1 - X5: OK
    function _swap(
        address fromToken,
        address toToken,
        uint256 amountIn,
        address to
    ) internal returns (uint256 amountOut) {
        // Checks
        // X1 - X5: OK
        IUniswapV2Pair pair =
        IUniswapV2Pair(factory.getPair(fromToken, toToken));
        require(address(pair) != address(0), "SunMaker: Cannot convert");

        // Interactions
        // X1 - X5: OK
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        uint256 amountInWithFee = amountIn.mul(997);
        if (fromToken == pair.token0()) {
            amountOut =
            amountIn.mul(997).mul(reserve1) /
            reserve0.mul(1000).add(amountInWithFee);
            IERC20(fromToken).safeTransfer(address(pair), amountIn);
            pair.swap(0, amountOut, to, new bytes(0));
            // TODO: Add maximum slippage?
        } else {
            amountOut =
            amountIn.mul(997).mul(reserve0) /
            reserve1.mul(1000).add(amountInWithFee);
            IERC20(fromToken).safeTransfer(address(pair), amountIn);
            pair.swap(amountOut, 0, to, new bytes(0));
            // TODO: Add maximum slippage?
        }
    }

    // F1 - F10: OK
    // C1 - C24: OK
    function _toGovToken(address token, uint256 amountIn)
    internal
    returns (uint256 amountOut)
    {
        // X1 - X5: OK
        amountOut = _swap(token, govToken, amountIn, den);
    }

    // Update the status of the operator
    function updateOperator(address _operator, bool _status) external onlyOwner {
        operators[_operator] = _status;
        emit OperatorUpdated(_operator, _status);
    }

    function recoverToken(address tokenAddress) public onlyOwner {
        IERC20(tokenAddress).transfer(owner(), IERC20(tokenAddress).balanceOf(address(this)));
    }
}