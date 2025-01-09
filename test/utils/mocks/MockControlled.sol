// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ControlledUpgradeable} from "../../../src/deployment/ControlledUpgradeable.sol";

contract MockControlled is ControlledUpgradeable {

    function initialize(address initialOwner) public initializer {
        __AccessControlDefaultAdminRules_init_unchained(0, initialOwner);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function reinitialize(address upgrader) external reinitializer(2) {
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    function version() public pure returns (int) {
        return 1;
    }
}
