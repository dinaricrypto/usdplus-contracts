// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {StorkStructs} from "./StorkStructs.sol";

/// @notice Interface for getting temporal numeric values from Stork

interface IStorkTemporalNumericValueUnsafeGetter {
    function getTemporalNumericValueUnsafeV1(bytes32 id)
        external
        view
        returns (StorkStructs.TemporalNumericValue memory value);
}
