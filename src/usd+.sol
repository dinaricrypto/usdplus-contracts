// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @notice stablecoin
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/usd+.sol)
contract usdplus is ERC20Permit {
    constructor() ERC20("USD+", "USD+") ERC20Permit("USD+") {}
}
