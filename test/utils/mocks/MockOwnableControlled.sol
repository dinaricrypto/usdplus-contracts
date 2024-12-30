// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ControlledUpgradeable} from "../../../src/deployment/ControlledUpgradeable.sol";

contract MockOwnableControlled is ControlledUpgradeable {
    uint256 private _value;

    function initialize(address initialOwner) public initializer {
        __AccessControlDefaultAdminRules_init_unchained(0, initialOwner);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function reinitialize(address initialOwner, address upgrader, string memory newVersion) external reinitializer(2) {
        __ControlledUpgradeable_init(initialOwner, upgrader, newVersion);
    }
}
