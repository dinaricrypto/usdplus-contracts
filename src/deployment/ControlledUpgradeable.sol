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

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

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

    function version() external view returns (string memory) {
        return _version;
    }
}
