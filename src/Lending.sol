// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin-contracts/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

error TransferFailed();
error TokenNotAllowed(address token);
error NeedsMoreThanZero();

contract Lending is ReentrancyGuard, Ownable {
    mapping(address => address) public s_tokenToPriceFeed;
    address[] public s_allowedTokens;
    // Account -> token-> Amount
    mapping(address => mapping(address => uint256))
        public s_accountToTokenDeposits;
    // account -> token -> amount
    mapping(address => mapping(address => uint256))
        public s_accountToTokenBorrows;

    // 5% liquidation reward
    uint256 public constant LIQUIDATION_REWARD = 5;
    uint256 public constant LIQUIDATION_THRESHOLD = 80;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;

    event AllowedTokenSet(address indexed token, address indexed priceFeed);
    event Deposit(
        address indexed account,
        address indexed token,
        uint256 indexed amount
    );
    event Borrow(
        address indexed account,
        address indexed token,
        uint256 indexed amount
    );
    event Withdraw(
        address indexed account,
        address indexed token,
        uint256 indexed amount
    );
    event Repay(
        address indexed account,
        address indexed token,
        uint256 indexed amount
    );
    event Liquidate(
        address indexed account,
        address indexed repayToken,
        address indexed rewardToken,
        uint256 halfDebtInEth,
        address liquidator
    );

    modifier isAllowedtoken(address token) {
        if (s_tokenToPriceFeed[token] == address(0))
            revert TokenNotAllowed(token);
        _;
    }

    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert NeedsMoreThanZero();
        }
        _;
    }

    function setAllowedToken(
        address token,
        address priceFeed
    ) external onlyOwner {
        bool foundToken = false;
        uint256 allowedTokensLength = s_allowedTokens.length;
        for (uint256 index = 0; index < allowedTokensLength; index++) {
            if (s_allowedTokens[index] == token) {
                foundToken = true;
                break;
            }
        }
        if (!foundToken) {
            s_allowedTokens.push(token);
        }
        s_tokenToPriceFeed[token] = priceFeed;
        emit AllowedTokenSet(token, priceFeed);
    }

    function repay(
        address token,
        uint256 amount
    ) external nonReentrant isAllowedtoken(token) moreThanZero(amount) {
        emit Repay(msg.sender, token, amount);
        _repay(msg.sender, token, amount);
    }

    function _repay(address account, address token, uint256 amount) private {
        s_accountToTokenBorrows[account][token] -= amount;
        bool success = IERC20(token).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!success) revert TransferFailed();
    }

    function deposit(
        address token,
        uint256 amount
    ) external nonReentrant isAllowedtoken(token) moreThanZero(amount) {
        emit Deposit(msg.sender, token, amount);
        s_accountToTokenDeposits[msg.sender][token] += amount;
        bool success = IERC20(token).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        if (!success) revert TransferFailed();
    }

    function withdraw(
        address token,
        uint256 amount
    ) external nonReentrant moreThanZero(amount) {
        require(
            s_accountToTokenDeposits[msg.sender][token] >= amount,
            "Not enough funds"
        );
        emit Withdraw(msg.sender, token, amount);
        _pullFunds(msg.sender, token, amount);
        require(condition);
    }

    function healthFactor(address account) public view returns (uint256) {
        (
            uint256 borrowedValueInEth,
            uint256 collateralValueInEth
        ) = getAccountInformation(account);
    }

    function getAccountInformation(
        address user
    )
        public
        view
        returns (uint256 borrowedValueInETH, uint256 collateralValueInETH)
    {
        borrowedValueInETH = getAccountBorrowedValue(user);
        collateralValueInETH = getAccountCollateralValue(user);
    }

    function getAccountCollateralValue(
        address user
    ) public view returns (uint256) {
        uint256 totalCollateralValueInETH = 0;
        for (uint256 index = 0; index < s_allowedTokens.length; index++) {
            address token = s_allowedTokens[index];
            uint256 amount = s_accountToTokenDeposits[user][token];
            uint256 valueInETH = getEthValue(token, amount);
            totalCollateralValueInETH += valueInETH;
        }
        return totalCollateralValueInETH;
    }

    function getAccountBorrowedValue(
        address user
    ) public view returns (uint256) {
        uint256 totalBorrowsValueInETH = 0;
        for (uint256 index = 0; index < s_allowedTokens.length; index++) {
            address token = s_allowedTokens[index];
            uint256 amount = s_accountToTokenBorrows[user][token];
            uint256 valueInEth = getEthValue(token, amount);
            totalBorrowsValueInETH += valueInEth;
        }
        return totalBorrowsValueInETH;
    }

    function getEthValue(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_tokenToPriceFeed[token]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return (uint256(price) * amount) / 1e18;
    }

    function getTokenValueFromEth(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_tokenToPriceFeed[token]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return (amount * 1e18) / uint256(price);
    }

    function _pullFunds(
        address account,
        address token,
        uint256 amount
    ) private {
        require(
            s_accountToTokenDeposits[account][token] >= amount,
            "Not enough funds to withdraw"
        );
        s_accountToTokenDeposits[account][token] -= amount;
        bool success = IERC20(token).transfer(msg.sender, amount);
        if (!success) revert TransferFailed();
    }
}
