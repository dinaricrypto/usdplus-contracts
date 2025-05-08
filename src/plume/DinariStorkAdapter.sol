// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {IStorkTemporalNumericValueUnsafeGetter, StorkStructs} from "./IStorkTemporalNumericValueUnsafeGetter.sol";

/// @notice A port of the Chainlink AggregatorV3 interface that supports Stork price feeds
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/plume/DinariStorkAdapter.sol)
/// @dev Adapted from Stork's price feed system, used by Dinari to set price feeds via Plume

contract DinariStorkAdapter {
    bytes32 public immutable priceId;
    IStorkTemporalNumericValueUnsafeGetter public immutable stork;

    constructor(address _stork, bytes32 _priceId) {
        priceId = _priceId;
        stork = IStorkTemporalNumericValueUnsafeGetter(_stork);
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function description() public pure returns (string memory) {
        return "A port of a chainlink aggregator powered by Stork";
    }

    function version() public pure returns (uint256) {
        return 1;
    }

    function latestAnswer() public view virtual returns (int256) {
        return stork.getTemporalNumericValueUnsafeV1(priceId).quantizedValue;
    }

    // in nanoseconds
    function latestTimestamp() public view returns (uint256) {
        return stork.getTemporalNumericValueUnsafeV1(priceId).timestampNs;
    }

    function latestRound() public view returns (uint256) {
        // use timestamp in nanoseconds as the round id
        return latestTimestamp();
    }

    function getAnswer(uint256) public view returns (int256) {
        return latestAnswer();
    }

    // in nanoseconds
    function getTimestamp(uint256) external view returns (uint256) {
        return latestTimestamp();
    }

    /*
    * @notice This is exactly the same as `latestRoundData`, just including for parity with Chainlink
    * Stork doesn't store roundId on chain so there's no way to access old data by round id
    * Note that timestamps are in nanoseconds
    */
    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        StorkStructs.TemporalNumericValue memory value = stork.getTemporalNumericValueUnsafeV1(priceId);
        return (_roundId, value.quantizedValue, value.timestampNs, value.timestampNs, _roundId);
    }

    // timestamps are in nanoseconds
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        StorkStructs.TemporalNumericValue memory value = stork.getTemporalNumericValueUnsafeV1(priceId);
        roundId = uint80(value.timestampNs);
        return (roundId, value.quantizedValue, value.timestampNs, value.timestampNs, roundId);
    }
}
