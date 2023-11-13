// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.23;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DoubleEndedQueue} from "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UsdPlus, ITransferRestrictor} from "./UsdPlus.sol";

/// @notice stablecoin yield vault
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/UsdPlusPlus.sol)
contract StakedUsdPlus is ERC4626, ERC20Permit, Ownable {
    // TODO: continuous yield?
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;

    struct Lock {
        uint48 endTime;
        uint104 assets;
        uint104 shares;
    }

    // pack into single slot
    struct LockTotals {
        uint128 assets;
        uint128 shares;
    }

    event LockDurationSet(uint48 duration);

    error ValueOverflow();
    error LockTimeTooShort(uint256 wait);
    error ValueLocked(uint256 freeValue);

    /// @notice lock duration in seconds
    uint48 public lockDuration = 30 days;

    // dequeue of locks per account
    // back == most recent lock
    mapping(address => DoubleEndedQueue.Bytes32Deque) private _locks;

    // cached lock totals per account
    mapping(address => LockTotals) private _cachedLockTotals;

    constructor(UsdPlus usdplus, address initialOwner)
        ERC4626(usdplus)
        ERC20Permit("stUSD+")
        ERC20("stUSD+", "stUSD+")
        Ownable(initialOwner)
    {}

    function decimals() public view virtual override(ERC4626, ERC20) returns (uint8) {
        return ERC4626.decimals();
    }

    /// @notice locked stUSD+ for account
    /// @dev Warning: can be stale, call refreshLocks to update
    function sharesLocked(address account) external view returns (uint256) {
        return _cachedLockTotals[account].shares;
    }

    /// @notice complete lock schedule for account
    function getLockSchedule(address account) external view returns (Lock[] memory) {
        uint256 n = _locks[account].length();
        Lock[] memory schedule = new Lock[](n);
        for (uint256 i = 0; i < n; i++) {
            schedule[i] = unpackLockData(_locks[account].at(i));
        }
        return schedule;
    }

    // ------------------ Admin ------------------

    /// @notice set lock duration
    function setLockDuration(uint48 duration) external onlyOwner {
        lockDuration = duration;
        emit LockDurationSet(duration);
    }

    // ------------------ Lock System ------------------

    /// @dev pack lock data into a single bytes32
    function packLockData(Lock memory lock) internal pure returns (bytes32) {
        return bytes32(uint256(lock.endTime) << 208 | uint256(lock.assets) << 104 | lock.shares);
    }

    /// @dev unpack lock data from a single bytes32
    function unpackLockData(bytes32 packed) internal pure returns (Lock memory) {
        uint256 packedInt = uint256(packed);
        return Lock(uint48(packedInt >> 208), uint104(packedInt >> 104), uint104(packedInt));
    }

    /// @dev add lock to queue and update cached totals
    function addLock(address account, uint256 assets, uint256 shares) internal {
        // TODO: update maxDeposit to precheck these limits
        if (assets > type(uint104).max) revert ValueOverflow();
        if (shares > type(uint104).max) revert ValueOverflow();

        // TODO: reduce gas by not loading locktotals twice, not peeking twice
        refreshLocks(account);

        // ensure new lock ends after previous lock
        // this means that if lockDuration is changed, users may have to wait before they can mint more stUSD+
        uint48 endTime = uint48(block.timestamp) + lockDuration;
        if (_locks[account].length() > 0) {
            Lock memory prevLock = unpackLockData(_locks[account].back());
            if (endTime < prevLock.endTime) revert LockTimeTooShort(prevLock.endTime - endTime);
        }
        _locks[account].pushBack(packLockData(Lock(endTime, uint104(assets), uint104(shares))));
        LockTotals memory cachedTotals = _cachedLockTotals[account];
        _cachedLockTotals[account] =
            LockTotals(uint128(cachedTotals.assets + assets), uint128(cachedTotals.shares + shares));
    }

    /// @dev remove expired locks and update cached totals
    function refreshLocks(address account) public {
        DoubleEndedQueue.Bytes32Deque storage locks = _locks[account];

        // remove expired locks
        uint128 assetsDecrement = 0;
        uint128 sharesDecrement = 0;
        while (locks.length() > 0) {
            Lock memory lock = unpackLockData(locks.front());
            // if lock is not expired, stop
            if (lock.endTime > block.timestamp) break;
            assetsDecrement += lock.assets;
            sharesDecrement += lock.shares;
            // slither-disable-next-line unused-return
            locks.popFront();
        }
        // update cached totals
        if (assetsDecrement > 0) {
            LockTotals memory cachedTotals = _cachedLockTotals[account];
            _cachedLockTotals[account] =
                LockTotals(cachedTotals.assets - assetsDecrement, cachedTotals.shares - sharesDecrement);
        }
    }

    /// @dev consume locks and update cached totals
    function consumeLocks(address account, uint256 sharesToConsume) internal returns (uint128) {
        if (sharesToConsume > type(uint128).max) revert ValueOverflow();

        DoubleEndedQueue.Bytes32Deque storage locks = _locks[account];

        uint128 assetsDue = 0;
        uint128 sharesRemaining = uint128(sharesToConsume);
        while (sharesRemaining > 0) {
            Lock memory lock = unpackLockData(locks.popFront());
            if (lock.shares > sharesRemaining) {
                // partially consume lock and return to queue
                uint128 assets = uint128(Math.mulDiv(lock.assets, sharesRemaining, lock.shares));
                assetsDue += assets;
                locks.pushFront(
                    packLockData(
                        Lock(lock.endTime, uint104(lock.assets - assets), uint104(lock.shares - sharesRemaining))
                    )
                );
                sharesRemaining = 0;
            } else {
                // fully consume lock
                assetsDue += lock.assets;
                sharesRemaining -= lock.shares;
            }
        }
        LockTotals memory cachedTotals = _cachedLockTotals[account];
        _cachedLockTotals[account] =
            LockTotals(cachedTotals.assets - assetsDue, cachedTotals.shares - uint128(sharesToConsume));
        return assetsDue;
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual override {
        // add lock on user mint
        addLock(receiver, assets, shares);
        super._deposit(caller, receiver, assets, shares);
    }

    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        virtual
        override
    {
        refreshLocks(owner);

        // if locked shares, determine how many assets to withdraw
        uint256 assetsToWithdraw = 0;

        // check if enough free shares
        uint128 lockedShares = _cachedLockTotals[owner].shares;
        if (lockedShares == 0) {
            // if no locked shares, withdraw at normal rate
            assetsToWithdraw = assets;
        } else {
            uint256 freeShares = balanceOf(owner) - lockedShares;
            if (shares > freeShares) {
                if (freeShares > 0) {
                    // if burning free shares, withdraw at normal rate
                    assetsToWithdraw += Math.mulDiv(assets, freeShares, shares);
                }
                // if burning locked shares, redeem for original USD+
                assetsToWithdraw += consumeLocks(owner, shares - freeShares);
            } else {
                // if not burning locked shares, withdraw at normal rate
                assetsToWithdraw = assets;
            }
        }

        // widthdraw assets
        super._withdraw(caller, receiver, owner, assetsToWithdraw, shares);
    }

    function _update(address from, address to, uint256 value) internal virtual override {
        // check if transfer is allowed
        UsdPlus(asset()).checkTransferRestricted(from, to);

        // transfer lock on recently minted stUSD+, minting and burning handled in _deposit and _withdraw
        if (from != address(0) && to != address(0)) {
            refreshLocks(from);

            // revert if not enough free shares
            uint256 freeShares = balanceOf(from) - _cachedLockTotals[from].shares;
            if (value > freeShares) revert ValueLocked(freeShares);
        }

        super._update(from, to, value);
    }

    function isBlacklisted(address account) external view returns (bool) {
        return UsdPlus(asset()).isBlacklisted(account);
    }
}
