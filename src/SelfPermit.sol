// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {MulticallUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/MulticallUpgradeable.sol";
import {IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

struct Permit {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
}

/// @notice Allows contract to call permit before other methods in the same transaction
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/SelfPermit.sol)
abstract contract SelfPermit is MulticallUpgradeable {
    error PermitFailure();

    /// @notice Permits this contract to spend a given token from `msg.sender`
    /// @dev The `spender` is always address(this).
    /// @param token The address of the token spent
    /// @param owner The address of the holder of the token
    /// @param value The amount that can be spent of token
    /// @param deadline A timestamp, the current blocktime must be less than or equal to this timestamp
    /// @param v Must produce valid secp256k1 signature from the holder along with `r` and `s`
    /// @param r Must produce valid secp256k1 signature from the holder along with `v` and `s`
    /// @param s Must produce valid secp256k1 signature from the holder along with `r` and `v`
    function selfPermit(address token, address owner, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        public
    {
        try IERC20Permit(token).permit(owner, address(this), value, deadline, v, r, s) {
            // success
            return;
        } catch {
            // Permit potentially got front-run. Continue if allowance is sufficient.
            if (IERC20(token).allowance(owner, address(this)) >= value) {
                return;
            }
        }

        revert PermitFailure();
    }
}
