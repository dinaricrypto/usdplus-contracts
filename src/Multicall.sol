// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import {Multicall as OZMulticall} from "@openzeppelin/contracts/utils/Multicall.sol";

/// @notice Standard multicall utility contract
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/Multicall.sol)
contract Multicall is OZMulticall {}
