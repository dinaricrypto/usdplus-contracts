// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockControlled, ControlledUpgradeable} from "../utils/mocks/MockControlled.sol";
import {MockControlledV2} from "../utils/mocks/MockControlledV2.sol";
import {MockOwnableUpgradeable} from "../utils/mocks/MockOwnable.sol";
import {MockOwnableControlled} from "../utils/mocks/MockOwnableControlled.sol";
import {MockUpgradeableContract} from "../utils/mocks/MockAccessControl.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {UsdPlus} from "../../src/UsdPlus.sol";

contract ControlledUpgradeableTest is Test {
    MockControlled controlled;
    MockOwnableUpgradeable ownable;
    MockOwnableControlled ownableControlled;
    MockUpgradeableContract upgradeableContract;
    MockControlledV2 controlledV2;

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

    function test_upgrade_access_control() public {
        MockControlled controlledImpl = new MockControlled();

        vm.expectRevert(ControlledUpgradeable.IncorrectVersion.selector);
        vm.prank(ADMIN);
        upgradeableContract.upgradeToAndCall(
            address(controlledImpl), abi.encodeWithSelector(MockControlled.reinitialize.selector, UPGRADER, "")
        );

        vm.prank(ADMIN);
        upgradeableContract.upgradeToAndCall(
            address(controlledImpl), abi.encodeWithSelector(MockControlled.reinitialize.selector, UPGRADER, "1.0.0")
        );

        // check if the upgrade is successful
        assertEq(upgradeableContract.hasRole(controlledImpl.UPGRADER_ROLE(), UPGRADER), true);
        assertEq(upgradeableContract.hasRole(upgradeableContract.DEFAULT_ADMIN_ROLE(), ADMIN), true);
        assertEq(MockControlled(address(upgradeableContract)).version(), "1.0.0");

        // // // upgrade with upgrader
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, ADMIN, controlledImpl.UPGRADER_ROLE()
            )
        );
        vm.prank(ADMIN);
        upgradeableContract.upgradeToAndCall(
            address(controlledImpl), abi.encodeWithSelector(MockControlled.reinitialize.selector, UPGRADER, "1.0.1")
        );

        MockControlledV2 controlledV2Impl = new MockControlledV2();

        // version is the same as previous one
        vm.expectRevert(ControlledUpgradeable.IncorrectVersion.selector);
        vm.prank(UPGRADER);
        upgradeableContract.upgradeToAndCall(
            address(controlledV2Impl), abi.encodeWithSelector(controlledV2Impl.reinitialize.selector, "1.0.0")
        );

        vm.prank(UPGRADER);
        upgradeableContract.upgradeToAndCall(
            address(controlledV2Impl), abi.encodeWithSelector(controlledV2Impl.reinitialize.selector, "1.0.1")
        );
        assertEq(MockControlled(address(upgradeableContract)).version(), "1.0.1");
    }

    function test_ugprade_ownable() public {
        assertEq(ownable.owner(), ADMIN);
        MockOwnableControlled ownableControlledImpl = new MockOwnableControlled();

        vm.expectRevert(ControlledUpgradeable.IncorrectVersion.selector);
        vm.prank(ADMIN);
        ownable.upgradeToAndCall(
            address(ownableControlledImpl),
            abi.encodeWithSelector(MockOwnableControlled.reinitialize.selector, ADMIN, UPGRADER, "")
        );

        vm.prank(ADMIN);
        ownable.upgradeToAndCall(
            address(ownableControlledImpl),
            abi.encodeWithSelector(MockOwnableControlled.reinitialize.selector, ADMIN, UPGRADER, "1.0.0")
        );
        assertEq(
            MockOwnableControlled(address(ownable)).hasRole(ownableControlledImpl.DEFAULT_ADMIN_ROLE(), ADMIN), true
        );
        assertEq(MockOwnableControlled(address(ownable)).hasRole(ownableControlledImpl.UPGRADER_ROLE(), UPGRADER), true);
        assertEq(MockOwnableControlled(address(ownable)).version(), "1.0.0");

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, ADMIN, ownableControlledImpl.UPGRADER_ROLE()
            )
        );
        vm.prank(ADMIN);
        ownable.upgradeToAndCall(
            address(ownableControlledImpl),
            abi.encodeWithSelector(MockOwnableControlled.reinitialize.selector, ADMIN, UPGRADER)
        );
    }
}
