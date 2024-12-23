// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ControlledUpgradeable} from "../../../src/deployment/ControlledUpgradeable.sol";

contract MockControlled is ControlledUpgradeable {
    uint256 private _value;

    function initialize(address admin) public initializer {
        __AccessControlDefaultAdminRules_init(0, admin);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function setValue(uint256 newValue) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _value = newValue;
    }

    function getValue() external view returns (uint256) {
        return _value;
    }

    function reinitialize(address originalOwner, address upgrader) external reinitializer(2) {
        _grantRole(DEFAULT_ADMIN_ROLE, originalOwner);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    function version() external pure virtual override returns (string memory) {
        return "2";
    }
}