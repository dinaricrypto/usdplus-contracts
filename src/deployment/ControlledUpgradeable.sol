// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";

abstract contract ControlledUpgradeable is UUPSUpgradeable, AccessControlDefaultAdminRulesUpgradeable {
    /// ------------------ Types ------------------ ///

    struct ControlledUpgradeableStorage {
        string version;
    }

    error IncorrectVersion();

    /// ------------------ Constants ------------------ ///

    bytes32 private constant STORAGE_LOCATION = 0xa933624b632dafb6269f971e02871383bdb4df65519e96d8286ae3da6fe4e3d6;
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// ------------------ Storage ------------------ ///

    function _getControlledStorage() private pure returns (ControlledUpgradeableStorage storage $) {
        assembly {
            $.slot := STORAGE_LOCATION
        }
    }

    /// ------------------ Modifiers ------------------ ///

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    /// ------------------ Initialization ------------------ ///
    // slither-disable-next-line naming-convention
    function __ControlledUpgradeable_init(address initialOwner, address upgrader, string memory newVersion) internal {
        __AccessControlDefaultAdminRules_init_unchained(0, initialOwner);
        _grantRole(UPGRADER_ROLE, upgrader);
        _setVersion(newVersion);
    }

    /// ------------------ Setters ------------------ ///

    /// @notice Set the version of the contract
    function _setVersion(string memory newVersion) internal {
        ControlledUpgradeableStorage storage $ = _getControlledStorage();
        // Revert if new version is empty OR if it's the same as current version
        if (
            bytes(newVersion).length == 0
                || (
                    bytes($.version).length != 0
                        && keccak256(abi.encodePacked($.version)) == keccak256(abi.encodePacked(newVersion))
                )
        ) {
            revert IncorrectVersion();
        }
        $.version = newVersion;
    }

    /// ------------------ Getters ------------------ ///

    function version() external view returns (string memory) {
        ControlledUpgradeableStorage storage $ = _getControlledStorage();
        return $.version;
    }
}
