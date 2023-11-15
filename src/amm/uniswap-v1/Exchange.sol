// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

interface IExchange {
    function ethToTokenSwap(uint256 expectedTokenAmount) external payable;

    function ethToTokenTransfer(
        uint256 expectedTokenAmount,
        address recipient
    ) external payable;
}

interface IFactory {
    function getExchange(address tokenAddress) external returns (address);
}

contract Exchange is ERC20 {
    address public tokenAddress;
    address public factoryAddress;

    event TokenPurchase(
        address indexed buyer,
        uint256 indexed ethSold,
        uint256 tokenBought
    );
    event EthPurchase(
        address indexed buyer,
        uint256 indexed tokenSold,
        uint256 ethBought
    );
    event AddLiquidity(
        address indexed provider,
        uint256 indexed ethAmount,
        uint256 indexed tokenAmount
    );

    event RemoveLiquidity(
        address indexed provider,
        uint256 indexed ethAmount,
        uint256 indexed tokenAmount
    );

    constructor(address token) ERC20("Funnyswap V1", "FUN-V1") {
        require(token != address(0), "invalid token address");
        tokenAddress = token;
        factoryAddress = msg.sender;
    }

    function addLiquidity(
        uint256 tokenAmount
    ) public payable returns (uint256 poolTokenAmount) {
        (uint256 tokenReserve, uint256 ethReserve) = getReserves();
        if (tokenReserve == 0) {
            IERC20 token = IERC20(tokenAddress);
            token.transferFrom(msg.sender, address(this), tokenAmount);
            poolTokenAmount = ethReserve;
        } else {
            ethReserve -= msg.value;
            uint256 expectedTokenAmount = (msg.value * tokenReserve) /
                ethReserve;
            require(
                tokenAmount >= expectedTokenAmount,
                "Insufficient token amount"
            );
            IERC20 token = IERC20(tokenAddress);
            token.transferFrom(msg.sender, address(this), expectedTokenAmount);
            poolTokenAmount = (totalSupply() * msg.value) / ethReserve;
        }
        _mint(msg.sender, poolTokenAmount);
        emit AddLiquidity(msg.sender, msg.value, tokenAmount);
    }

    function removeLiquidity(
        uint256 poolTokenAmount
    ) public returns (uint256 ethAmount, uint256 tokenAmount) {
        require(poolTokenAmount > 0, "Amount of pool token cannot be 0");
        (uint256 tokenReserve, uint256 ethReserve) = getReserves();
        ethAmount = (ethReserve * poolTokenAmount) / totalSupply();
        tokenAmount = (tokenReserve * poolTokenAmount) / totalSupply();
        _burn(msg.sender, poolTokenAmount);
        (bool sent, ) = (msg.sender).call{value: ethAmount}("");
        require(sent, "Failed to send Eth");
        IERC20(tokenAddress).transfer(msg.sender, tokenAmount);
        emit RemoveLiquidity(msg.sender, ethAmount, tokenAmount);
    }

    function getAmount(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) private pure returns (uint256 outputAmount) {
        require(
            inputReserve > 0 && outputReserve > 0,
            "Reserves cannot be null"
        );
        uint256 inputAmountWithFee = inputAmount * 997;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (1000 * inputReserve + inputAmountWithFee);
        outputAmount = numerator / denominator;
    }

    function getTokenAmount(
        uint256 ethAmount
    ) public view returns (uint256 tokenAmount) {
        require(ethAmount > 0, "Eth amount cannot be null");
        (uint256 tokenReserve, uint256 ethReserve) = getReserves();
        tokenAmount = getAmount(ethAmount, ethReserve, tokenReserve);
    }

    function getEthAmount(
        uint256 tokenAmount
    ) public view returns (uint256 ethAmount) {
        require(tokenAmount > 0, "token amount cannot be null");
        (uint256 tokenReserve, uint256 ethReserve) = getReserves();
        ethAmount = getAmount(tokenAmount, tokenReserve, ethReserve);
    }

    function getReserves()
        public
        view
        returns (uint256 tokenReserve, uint256 ethReserve)
    {
        tokenReserve = IERC20(tokenAddress).balanceOf(address(this));
        ethReserve = address(this).balance;
    }

    function ethToToken(
        uint256 expectedToTokenAmount,
        address recipient
    ) private {
        (uint256 tokenReserve, uint256 ethReserve) = getReserves();
        uint256 tokenAmount = getAmount(
            msg.value,
            ethReserve - msg.value,
            tokenReserve
        );
        require(tokenAmount >= expectedToTokenAmount, "token amount low");
        IERC20(tokenAddress).transfer(recipient, tokenAmount);
        emit TokenPurchase(recipient, msg.value, tokenAmount);
    }

    function ethToTokenTransfer(
        uint256 expectedTokenAmount,
        address recipient
    ) public payable {
        ethToToken(expectedTokenAmount, recipient);
    }

    function ethToTokenSwap(uint256 expectedTokenAmount) public payable {
        ethToToken(expectedToTokenAmount, msg.sender);
    }

    function tokenToEthSwap(
        uint256 tokenAmount,
        uint256 expectedEthAmount
    ) public {
        (uint256 tokenReserve, uint256 ethReserve) = getReserves();
        uint256 ethAmount = getAmount(tokenAmount, tokenReserve, ethReserve);
        require(ethAmount >= expectedEthAmount, "Eth amount low");
        IERC20(tokenAddress).transferFrom(
            msg.sender,
            address(this),
            tokenAmount
        );
        (bool sent, ) = (msg.sender).call{value: ethAmount}("");
        require(sent, "failed to send ether");
        emit EthPurchase(msg.sender, tokenAmount, ethAmount);
    }

    function tokenToTokenSwap(
        uint256 tokenAmount,
        uint256 expectedTargetTokenAmount,
        address targetTokenAddress
    ) public {
        require(targetTokenAddress != address(0), "token address not valid");
        require(tokenAmount > 0, "token amount not valid");
        address targetExchangeAddress = IFactory(factoryAddress).getExchange(
            targetTokenAddress
        );
        require(
            targetExchangeAddress != address(this) &&
                targetTokenAddress != address(0),
            "exchange address not valid"
        );
        (uint256 tokenReserve, uint256 ethReserve) = getReserves();
        uint256 ethAmount = getAmount(inputAmount, inputReserve, outputReserve);
        IERC20(tokenAddress).transferFrom(
            msg.sender,
            address(this),
            tokenAmount
        );

        IExchange(targetExchangeAddress).ethToTokenTransfer{value: ethAmount}(
            expectedTargetTokenAmount,
            msg.sender
        );
    }
}
