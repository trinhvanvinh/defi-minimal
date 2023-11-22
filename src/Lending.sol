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

    function deposit(
        address token,
        uint256 amount
    ) external nonReentrant isAll {}
}
