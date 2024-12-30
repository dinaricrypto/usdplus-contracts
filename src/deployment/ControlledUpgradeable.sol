// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";

abstract contract ControlledUpgradeable is UUPSUpgradeable, AccessControlDefaultAdminRulesUpgradeable {
    /// ------------------ Types ------------------ ///
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    string private _version;

    error IncorrectVersion();

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
        // Revert if new version is empty OR if it's the same as current version
        if (
            bytes(newVersion).length == 0
                || (
                    bytes(_version).length != 0
                        && keccak256(abi.encodePacked(_version)) == keccak256(abi.encodePacked(newVersion))
                )
        ) {
            revert IncorrectVersion();
        }
        _version = newVersion;
    }

    /// ------------------ Getters ------------------ ///

    function version() external view returns (string memory) {
        return _version;
    }
}
