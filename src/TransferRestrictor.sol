// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {ControlledUpgradeable} from "./deployment/ControlledUpgradeable.sol";
import {ITransferRestrictor} from "./ITransferRestrictor.sol";

/// @notice Enforces transfer restrictions
/// @author Dinari (https://github.com/dinaricrypto/sbt-contracts/blob/main/src/TransferRestrictor.sol)
/// Maintains a single `owner` who can add or remove accounts from `isBlacklisted`
contract TransferRestrictor is ControlledUpgradeable, ITransferRestrictor {
    /// ------------------ Types ------------------ ///

    struct TransferRestrictorStorage {
        mapping(address => bool) isBlacklisted;
    }

    /// @dev Account is restricted
    error AccountRestricted();

    /// @dev Emitted when `account` is added to `isBlacklisted`
    event Restricted(address indexed account);
    /// @dev Emitted when `account` is removed from `isBlacklisted`
    event Unrestricted(address indexed account);

    /// ------------------ Constants ------------------ ///

    bytes32 private constant TRANSFER_RESTRICTOR_STORAGE_LOCATION =
        0xbac1ed68b71f55caab6cd9be1e2e97a07e4f1b72103add3e5df1512b4068d902;

    /// @notice Role for approved distributors
    bytes32 public constant RESTRICTOR_ROLE = keccak256("RESTRICTOR_ROLE");

    /// ------------------ Storage ------------------ ///

    function _getTransferRestrictorStorage() private pure returns (TransferRestrictorStorage storage $) {
        assembly {
            $.slot := TRANSFER_RESTRICTOR_STORAGE_LOCATION
        }
    }

    /// ------------------ Version ------------------ ///

    function version() public pure returns (uint8) {
        return 1;
    }

    /// ------------------ Initialization ------------------ ///

    function initialize(address initialOwner, address upgrader) public initializer {
        __ControlledUpgradeable_init(initialOwner, upgrader);
        _grantRole(RESTRICTOR_ROLE, initialOwner);
    }

    /// ------------------ Setters ------------------ ///

    /// @notice Restrict `account` from sending or receiving tokens
    /// @dev Does not check if `account` is restricted
    /// Can only be called by `RESTRICTOR_ROLE`
    function restrict(address account) external onlyRole(RESTRICTOR_ROLE) {
        TransferRestrictorStorage storage $ = _getTransferRestrictorStorage();
        $.isBlacklisted[account] = true;
        emit Restricted(account);
    }

    /// @notice Unrestrict `account` from sending or receiving tokens
    /// @dev Does not check if `account` is restricted
    /// Can only be called by `RESTRICTOR_ROLE`
    function unrestrict(address account) external onlyRole(RESTRICTOR_ROLE) {
        TransferRestrictorStorage storage $ = _getTransferRestrictorStorage();
        $.isBlacklisted[account] = false;
        emit Unrestricted(account);
    }

    /// ------------------ Transfer Restriction ------------------ ///

    /// @inheritdoc ITransferRestrictor
    function requireNotRestricted(address from, address to) external view virtual {
        TransferRestrictorStorage storage $ = _getTransferRestrictorStorage();
        if ($.isBlacklisted[from] || $.isBlacklisted[to]) {
            revert AccountRestricted();
        }
    }

    /// ------------------ Getters ------------------ ///
    /// @notice Accounts in `isBlacklisted` cannot send or receive tokens
    function isBlacklisted(address account) public view returns (bool) {
        TransferRestrictorStorage storage $ = _getTransferRestrictorStorage();
        return $.isBlacklisted[account];
    }
}
