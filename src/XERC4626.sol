// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC4626Upgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "ERC4626-Contracts/interfaces/IxERC4626.sol";

/**
 * @title  An xERC4626 Single Staking Contract
 *  @notice This contract allows users to autocompound rewards denominated in an underlying reward token. 
 *          It is fully compatible with [ERC4626](https://eips.ethereum.org/EIPS/eip-4626) allowing for DeFi composability.
 *          It maintains balances using internal accounting to prevent instantaneous changes in the exchange rate.
 *          NOTE: an exception is at contract creation, when a reward cycle begins before the first deposit. After the first deposit, exchange rate updates smoothly.
 *
 *          Operates on "cycles" which distribute the rewards surplus over the internal balance to users linearly over the remainder of the cycle window.
 *  @author Modified from ERC4626-Alliance (https://github.com/ERC4626-Alliance/ERC4626-Contracts/blob/main/src/xERC4626.sol)
 */
abstract contract XERC4626 is IxERC4626, ERC4626Upgradeable {
    using SafeCast for uint256;

    /// ------------------ Storage ------------------

    struct XERC4626Storage {
        // the maximum length of a rewards cycle (immutable)
        uint32 _rewardsCycleLength;
        // the effective start of the current cycle
        uint32 _lastSync;
        // the end of the current cycle. Will always be evenly divisible by `rewardsCycleLength`.
        uint32 _rewardsCycleEnd;
        // the amount of rewards distributed in the most recent cycle.
        uint192 _lastRewardAmount;
        // the total assets stored in the contract
        uint256 _storedTotalAssets;
    }

    // keccak256(abi.encode(uint256(keccak256("dinaricrypto.storage.XERC4626")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant XERC4626_STORAGE_LOCATION =
        0x84effe3e8580e30823cd9bf5ba46a7cf87c4db2b5d227f27fc8a60d876aad700;

    function _getXERC4626Storage() private pure returns (XERC4626Storage storage $) {
        assembly {
            $.slot := XERC4626_STORAGE_LOCATION
        }
    }

    /// ------------------ Initialization ------------------

    function __XERC4626_init(uint32 _rewardsCycleLength) internal {
        XERC4626Storage storage $ = _getXERC4626Storage();
        $._rewardsCycleLength = _rewardsCycleLength;
        // seed initial rewardsCycleEnd
        $._rewardsCycleEnd = (block.timestamp.toUint32() / _rewardsCycleLength) * _rewardsCycleLength;
    }

    /// ------------------ XERC4626 ------------------

    /// @notice Compute the amount of tokens available to share holders.
    ///         Increases linearly during a reward distribution period from the sync call, not the cycle start.
    function totalAssets() public view override returns (uint256) {
        XERC4626Storage storage $ = _getXERC4626Storage();
        // cache global vars
        uint256 storedTotalAssets_ = $._storedTotalAssets;
        uint192 lastRewardAmount_ = $._lastRewardAmount;
        uint32 rewardsCycleEnd_ = $._rewardsCycleEnd;
        uint32 lastSync_ = $._lastSync;

        if (block.timestamp >= rewardsCycleEnd_) {
            // no rewards or rewards fully unlocked
            // entire reward amount is available
            return storedTotalAssets_ + lastRewardAmount_;
        }

        // rewards not fully unlocked
        // add unlocked rewards to stored total
        uint256 unlockedRewards = (lastRewardAmount_ * (block.timestamp - lastSync_)) / (rewardsCycleEnd_ - lastSync_);
        return storedTotalAssets_ + unlockedRewards;
    }

    // Update storedTotalAssets on withdraw/redeem
    function _withdraw(address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares) internal virtual override {
        XERC4626Storage storage $ = _getXERC4626Storage();
        $._storedTotalAssets -= assets;

        super._withdraw(caller, receiver, owner, assets, shares);
    }

    // Update storedTotalAssets on deposit/mint
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal virtual override {
        XERC4626Storage storage $ = _getXERC4626Storage();
        $._storedTotalAssets += assets;

        super._deposit(caller, receiver, assets, shares);
    }

    /// @notice Distributes rewards to xERC4626 holders.
    /// All surplus `asset` balance of the contract over the internal balance becomes queued for the next cycle.
    function syncRewards() public virtual {
        XERC4626Storage storage $ = _getXERC4626Storage();
        uint192 lastRewardAmount_ = $._lastRewardAmount;
        uint32 timestamp = block.timestamp.toUint32();

        if (timestamp < $._rewardsCycleEnd) revert SyncError();

        uint256 storedTotalAssets_ = $._storedTotalAssets;
        uint256 nextRewards = IERC20(asset()).balanceOf(address(this)) - storedTotalAssets_ - lastRewardAmount_;

        $._storedTotalAssets = storedTotalAssets_ + lastRewardAmount_; // SSTORE

        uint32 rewardsCycleLength_ = $._rewardsCycleLength;
        uint32 end = ((timestamp + rewardsCycleLength_) / rewardsCycleLength_) * rewardsCycleLength_;

        // Combined single SSTORE
        $._lastRewardAmount = nextRewards.toUint192();
        $._lastSync = timestamp;
        $._rewardsCycleEnd = end;

        emit NewRewardsCycle(end, nextRewards);
    }
}
