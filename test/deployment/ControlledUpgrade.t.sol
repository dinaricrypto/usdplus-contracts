// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockControlled} from "../utils/mocks/MockControlled.sol";
import {MockOwnableUpgradeable} from "../utils/mocks/MockOwnable.sol";
import {MockUpgradeableContract} from "../utils/mocks/MockAccessControl.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {UsdPlus} from "../../src/UsdPlus.sol";

contract ControlledUpgradeableTest is Test {
    MockControlled controlled;
    MockOwnableUpgradeable ownable;
    MockUpgradeableContract upgradeableContract;

    // constant
    address public constant ADMIN = address(0x1234);
    address public constant UPGRADER = address(0x1235);

    function setUp() public {
        MockOwnableUpgradeable ownableImpl = new MockOwnableUpgradeable();
        MockUpgradeableContract upgradeableContractImpl = new MockUpgradeableContract();

        upgradeableContract = MockUpgradeableContract(
            address(
                new ERC1967Proxy(
                    address(upgradeableContractImpl),
                    abi.encodeWithSelector(upgradeableContractImpl.initialize.selector, ADMIN)
                )
            )
        );

        ownable = MockOwnableUpgradeable(
            address(
                new ERC1967Proxy(address(ownableImpl), abi.encodeWithSelector(ownableImpl.initialize.selector, ADMIN))
            )
        );
    }

    function test_upgrade() public {
        MockControlled controlledImpl = new MockControlled();
        vm.prank(ADMIN);
        upgradeableContract.upgradeToAndCall(
            address(controlledImpl), abi.encodeWithSelector(MockControlled.reinitialize.selector, UPGRADER)
        );
    }
}
