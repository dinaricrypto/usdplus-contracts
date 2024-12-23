// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Ownable2StepUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";

contract MockOwnable is UUPSUpgradeable, Ownable2StepUpgradeable {
    uint256 private _value;

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function setValue(uint256 newValue) external onlyOwner {
        _value = newValue;
    }

    function getValue() external view returns (uint256) {
        return _value;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}