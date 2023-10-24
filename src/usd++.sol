// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice stablecoin yield vault
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/usd++.sol)
contract UsdPlusPlus is ERC4626, ERC20Permit {
    constructor(IERC20 usdplus) ERC4626(usdplus) ERC20Permit("USD++") ERC20("USD++", "USD++") {}

    function decimals() public view virtual override(ERC4626, ERC20) returns (uint8) {
        return ERC4626.decimals();
    }
}
