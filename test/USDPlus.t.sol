// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract UsdPlusTest is Test {
    event TreasurySet(address indexed treasury);

    UsdPlus usdplus;

    address public constant ADMIN = address(0x1234);
    address public constant TREASURY = address(0x1235);
    address public constant MINTER = address(0x1236);
    address public constant BURNER = address(0x1237);
    address public constant USER = address(0x1238);

    function setUp() public {
        usdplus = new UsdPlus(TREASURY, ADMIN);
    }

    function testTreasury(address treasury) public {
        // non-admin cannot set treasury
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), usdplus.DEFAULT_ADMIN_ROLE()
            )
        );
        usdplus.setTreasury(treasury);

        // admin can set treasury
        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit TreasurySet(treasury);
        usdplus.setTreasury(treasury);
        assertEq(usdplus.treasury(), treasury);
    }

    function testMint(uint256 amount) public {
        // non-minter cannot mint
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), usdplus.MINTER_ROLE()
            )
        );
        usdplus.mint(address(USER), amount);

        // grant minter role
        vm.startPrank(ADMIN);
        usdplus.grantRole(usdplus.MINTER_ROLE(), MINTER);
        vm.stopPrank();

        // minter can mint
        vm.prank(MINTER);
        usdplus.mint(address(USER), amount);
        assertEq(usdplus.balanceOf(address(USER)), amount);
    }

    function testBurn(uint256 amount) public {
        // mint USD+ to user for testing
        vm.startPrank(ADMIN);
        usdplus.grantRole(usdplus.MINTER_ROLE(), MINTER);
        vm.stopPrank();

        vm.prank(MINTER);
        usdplus.mint(address(USER), amount);

        // non-burner cannot burn
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(USER), usdplus.BURNER_ROLE()
            )
        );
        vm.prank(address(USER));
        usdplus.burn(amount);

        // grant burner role
        vm.startPrank(ADMIN);
        usdplus.grantRole(usdplus.BURNER_ROLE(), address(USER));
        vm.stopPrank();

        // burner can burn
        vm.prank(address(USER));
        usdplus.burn(amount);
        assertEq(usdplus.balanceOf(address(USER)), 0);
    }

    function testBurnFrom(uint256 amount) public {
        // mint USD+ to user for testing
        vm.startPrank(ADMIN);
        usdplus.grantRole(usdplus.MINTER_ROLE(), MINTER);
        vm.stopPrank();

        vm.prank(MINTER);
        usdplus.mint(address(USER), amount);

        // user approves burner
        vm.prank(address(USER));
        usdplus.approve(address(BURNER), amount);

        // non-burner cannot burn
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(BURNER), usdplus.BURNER_ROLE()
            )
        );
        vm.prank(address(BURNER));
        usdplus.burnFrom(address(USER), amount);

        // grant burner role
        vm.startPrank(ADMIN);
        usdplus.grantRole(usdplus.BURNER_ROLE(), address(BURNER));
        vm.stopPrank();

        // burner can burn
        vm.prank(address(BURNER));
        usdplus.burnFrom(address(USER), amount);
        assertEq(usdplus.balanceOf(address(USER)), 0);
    }
}
