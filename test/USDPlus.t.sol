// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import {TestUtils} from "./utils.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract UsdPlusTest is Test {
    event TreasurySet(address indexed treasury);

    UsdPlus usdplus;

    address public constant ADMIN = address(0x1234);
    address public constant TREASURY = address(0x1235);
    address public constant MINTER = address(0x1236);

    function setUp() public {
        usdplus = new UsdPlus(ADMIN);
    }

    function testTreasury() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), usdplus.DEFAULT_ADMIN_ROLE()
            )
        );
        usdplus.setTreasury(TREASURY);

        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit TreasurySet(TREASURY);
        usdplus.setTreasury(TREASURY);
        assertEq(usdplus.treasury(), TREASURY);
    }

    function testMint() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), usdplus.MINTER_ROLE()
            )
        );
        usdplus.mint(address(1), 100);

        vm.startPrank(ADMIN);
        usdplus.grantRole(usdplus.MINTER_ROLE(), MINTER);
        vm.stopPrank();

        vm.prank(MINTER);
        usdplus.mint(address(1), 100);
        assertEq(usdplus.balanceOf(address(1)), 100);
    }

    function testBurn() public {
        vm.startPrank(ADMIN);
        usdplus.grantRole(usdplus.MINTER_ROLE(), MINTER);
        vm.stopPrank();

        vm.prank(MINTER);
        usdplus.mint(address(1), 100);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(1), usdplus.BURNER_ROLE()
            )
        );
        vm.prank(address(1));
        usdplus.burn(100);

        vm.startPrank(ADMIN);
        usdplus.grantRole(usdplus.BURNER_ROLE(), address(1));
        vm.stopPrank();

        vm.prank(address(1));
        usdplus.burn(100);
        assertEq(usdplus.balanceOf(address(1)), 0);
    }

    function testBurnFrom() public {
        vm.startPrank(ADMIN);
        usdplus.grantRole(usdplus.MINTER_ROLE(), MINTER);
        vm.stopPrank();

        vm.prank(MINTER);
        usdplus.mint(address(1), 100);

        vm.prank(address(1));
        usdplus.approve(address(this), 100);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), usdplus.BURNER_ROLE()
            )
        );
        usdplus.burnFrom(address(1), 100);

        vm.startPrank(ADMIN);
        usdplus.grantRole(usdplus.BURNER_ROLE(), address(this));
        vm.stopPrank();

        usdplus.burnFrom(address(1), 100);
        assertEq(usdplus.balanceOf(address(1)), 0);
    }
}
