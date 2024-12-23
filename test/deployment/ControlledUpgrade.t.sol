// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MockControlled} from "../utils/mocks/MockControlled.sol";
import {MockOwnable} from "../utils/mocks/MockOwnable.sol";

contract ControlledUpgradeTest is Test {
    MockOwnable public implementation;
    MockControlled public implementationV2;
    ERC1967Proxy public proxy;
    MockOwnable public wrappedProxy;
    
    address public owner;
    address public upgrader;
    address public user;
    
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    function setUp() public {
        owner = makeAddr("owner");
        upgrader = makeAddr("upgrader");
        user = makeAddr("user");
        
        // Deploy implementation
        implementation = new MockOwnable();
        
        // Deploy proxy
        bytes memory initData = abi.encodeWithSelector(
            MockOwnable.initialize.selector,
            owner
        );
        
        proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        
        wrappedProxy = MockOwnable(address(proxy));
    }

    function test_InitialSetup() public {
        assertEq(wrappedProxy.owner(), owner);
        
        // Check owner can set value
        vm.prank(owner);
        wrappedProxy.setValue(42);
        assertEq(wrappedProxy.getValue(), 42);
        
        // Check non-owner cannot set value
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user);
        wrappedProxy.setValue(100);
    }

    function test_UpgradeToControlled() public {
        // Set initial state
        vm.prank(owner);
        wrappedProxy.setValue(42);
        
        // Deploy V2 implementation
        implementationV2 = new MockControlled();
        
        // Perform upgrade
        vm.prank(owner);
        // wrappedProxy.upgradeTo(address(implementationV2));
        wrappedProxy.upgradeToAndCall(address(implementationV2), "0x");
        
        // Cast to V2
        MockControlled wrappedProxyV2 = MockControlled(address(proxy));
        
        // Setup new roles
        vm.prank(owner);
        wrappedProxyV2.reinitialize(owner, upgrader);
        
        // Verify roles
        assertTrue(wrappedProxyV2.hasRole(wrappedProxyV2.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(wrappedProxyV2.hasRole(wrappedProxyV2.UPGRADER_ROLE(), upgrader));
        assertEq(wrappedProxyV2.version(), "2");
        
        // Verify state preserved
        assertEq(wrappedProxyV2.getValue(), 42);
    }

    function test_ReinitializeOnlyOnce() public {
        // Deploy and upgrade to V2
        implementationV2 = new MockControlled();
        vm.prank(owner);
        wrappedProxy.upgradeToAndCall(address(implementationV2), "0x");
        
        MockControlled wrappedProxyV2 = MockControlled(address(proxy));
        
        // First reinitialize should work
        vm.prank(owner);
        wrappedProxyV2.reinitialize(owner, upgrader);
        
        // Second should fail
        vm.expectRevert("Initializable: contract is already initialized");
        vm.prank(owner);
        wrappedProxyV2.reinitialize(owner, upgrader);
    }

    function test_NewPermissionsAfterUpgrade() public {
        // Deploy and upgrade to V2
        implementationV2 = new MockControlled();
        vm.startPrank(owner);
        wrappedProxy.upgradeToAndCall(address(implementationV2), "0x");
        
        MockControlled wrappedProxyV2 = MockControlled(address(proxy));
        wrappedProxyV2.reinitialize(owner, upgrader);
        vm.stopPrank();
        
        // Admin should be able to set value
        vm.prank(owner);
        wrappedProxyV2.setValue(100);
        assertEq(wrappedProxyV2.getValue(), 100);
        
        // Non-admin should not be able to set value
        vm.expectRevert("AccessControl: account 0x... is missing role ...");
        vm.prank(user);
        wrappedProxyV2.setValue(200);
        
        // Even upgrader cannot set value without admin role
        vm.expectRevert("AccessControl: account 0x... is missing role ...");
        vm.prank(upgrader);
        wrappedProxyV2.setValue(300);
    }

    function test_UpgraderRoleAfterUpgrade() public {
        // Deploy and upgrade to V2
        implementationV2 = new MockControlled();
        vm.prank(owner);
        wrappedProxy.upgradeToAndCall(address(implementationV2), "0x");
        
        MockControlled wrappedProxyV2 = MockControlled(address(proxy));
        vm.prank(owner);
        wrappedProxyV2.reinitialize(owner, upgrader);
        
        // Deploy another implementation for testing upgrade
        MockControlled implementationV3 = new MockControlled();
        
        // Owner cannot upgrade anymore
        vm.expectRevert("AccessControl: account 0x... is missing role ...");
        vm.prank(owner);
        wrappedProxyV2.upgradeToAndCall(address(implementationV3), "0x");
        
        // Only upgrader can upgrade
        vm.prank(upgrader);
        wrappedProxyV2.upgradeTo(address(implementationV3));
    }
}