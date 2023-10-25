// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {TimeData} from "./TimeData.sol";

/// @notice stablecoin yield vault
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/usd++.sol)
contract UsdPlusPlus is ERC4626, ERC20Permit {

    error ValueOverflow();

    // TODO: continuous yield?

    // TODO: view methods to get locked state

    uint40 public lockDuration = 30 days;

    // if we pack the amount and endtime into a uint256, what is the max mint amount?

    // locks need account, endtime, amount
    // mapping(address => EnumerableSet.UintSet) private _locks;
    // minheap of locks by endtime?

    constructor(IERC20 usdplus) ERC4626(usdplus) ERC20Permit("USD++") ERC20("USD++", "USD++") {}

    function decimals() public view virtual override(ERC4626, ERC20) returns (uint8) {
        return ERC4626.decimals();
    }

    // ------------------ Lock ------------------

    function packLockData(uint48 time, uint104 assets, uint104 shares) internal pure returns (uint256) {
        return uint256(time) << 208 | uint256(assets) << 104 | shares;
    }

    function unpackLockData(uint256 packed) internal pure returns (uint48, uint104, uint104) {
        return (uint40(packed >> 208), uint104(packed >> 104), uint104(packed));
    }

    // function addLock(address to, uint256 assets, uint256 shares) internal {
    //     if (assets > typeof(uint108).max) revert ValueOverflow();
    //     if (shares > typeof(uint108).max) revert ValueOverflow();

    //     _locks[to].add(packLockData(uint40(block.timestamp) + lockDuration, uint108(assets), uint108(shares)));
    // }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual override {
        // addLock(receiver, assets, shares);
        super._deposit(caller, receiver, assets, shares);
    }

    // on redeem, any locked amount is exchanged at original price

    // function totalLockedShares(address account) external view returns (uint256) {
    //     uint256[] memory locks = _locks[account].values();
    //     uint256 total = 0;
    //     for (uint256 i = 0; i < locks.length; i++) {
    //         (uint40 endTime,, uint256 shares) = unpackLockData(locks[i]);
    //         // if lock has not expired, add shares
    //         if (endTime > block.timestamp) {
    //             total += shares;
    //         }
    //     }
    //     return total;
    // }

    function _update(address from, address to, uint256 value) internal virtual override {
        // TODO: transfer lock on recently minted USD++, except when burning for original USD+
        if (from != address(0) && to != address(0)) {}
        super._update(from, to, value);
    }

    // TODO: blacklist
}
