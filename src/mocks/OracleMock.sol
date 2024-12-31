// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract OracleMock is AggregatorV3Interface {
    int256 public price = 1e8;

    function decimals() external pure returns (uint8) {
        return 8;
    }

    function description() external pure returns (string memory) {
        return "OracleMock";
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function getRoundData(uint80)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (0, price, 0, 0, 0);
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (0, price, 0, 0, 0);
    }

    function setPrice(int256 _price) external {
        price = _price;
    }
}
