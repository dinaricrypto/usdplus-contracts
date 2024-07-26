// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {MulticallUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/MulticallUpgradeable.sol";
import {IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol";

struct Permit {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
}

/// @notice Allows contract to call permit before other methods in the same transaction
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/Redeemer.sol)
abstract contract SelfPermit is MulticallUpgradeable {
    /// @notice Split a signature into `v`, `r`, `s` components
    /// @param sig The signature
    /// @param v secp256k1 signature from the holder along with `r` and `s`
    /// @param r signature from the holder along with `v` and `s`
    /// @param s signature from the holder along with `r` and `v`
    function splitSignature(bytes memory sig) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        assembly {
            r := mload(add(sig, 0x20))
            s := mload(add(sig, 0x40))
            v := byte(0, mload(add(sig, 0x60)))
        }
    }

    /// @notice Permits this contract to spend a given token from `msg.sender`
    /// @dev The `spender` is always address(this).
    /// @param token The address of the token spent
    /// @param permit The permit data
    /// @param signature The signature of the owner
    function selfPermit(address token, Permit calldata permit, bytes calldata signature) public {
        (uint8 v, bytes32 r, bytes32 s) = splitSignature(signature);
        IERC20Permit(token).permit(permit.owner, address(this), permit.value, permit.deadline, v, r, s);
    }
}
