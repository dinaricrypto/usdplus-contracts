// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ControlledUpgradeable} from "../../../src/deployment/ControlledUpgradeable.sol";

contract MockControlledV2 is ControlledUpgradeable {
    uint256 public value;

    function initialize(address initialOwner, address upgrader) public initializer {
        __AccessControlDefaultAdminRules_init_unchained(0, initialOwner);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function reinitialize(uint256 _value) external reinitializer(3) {
        value = _value;
    }

    function version() public pure returns (int) {
        return 2;
    }
}
