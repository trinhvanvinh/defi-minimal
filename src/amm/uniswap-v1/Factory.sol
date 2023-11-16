//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "./Exchange.sol";

contract Factory {
    mapping(address => address) public exchanges;

    function createExchange(
        address tokenAddress
    ) public returns (address exchangeAddress) {
        require(tokenAddress != address(0), "Token address not valid");
        require(
            exchanges[tokenAddress] == address(0),
            "Exchange already exists"
        );

        Exchange exchange = new Exchange(tokenAddress);
        exchanges[tokenAddress] = address(exchange);
        exchangeAddress = address(exchange);
    }
}
