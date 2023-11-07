// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {TransferRestrictor, ITransferRestrictor} from "../src/TransferRestrictor.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract UsdPlusTest is Test {
    event TreasurySet(address indexed treasury);
    event TransferRestrictorSet(ITransferRestrictor indexed transferRestrictor);

    TransferRestrictor transferRestrictor;
    UsdPlus usdplus;

    address public constant ADMIN = address(0x1234);
    address public constant TREASURY = address(0x1235);
    address public constant MINTER = address(0x1236);
    address public constant BURNER = address(0x1237);
    address public constant USER = address(0x1238);

    function setUp() public {
        transferRestrictor = new TransferRestrictor(ADMIN);
        usdplus = new UsdPlus(TREASURY, transferRestrictor, ADMIN);
    }

    function test_treasury(address treasury) public {
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

    function test_transferRestrictor(ITransferRestrictor _transferRestrictor) public {
        // non-admin cannot set transfer restrictor
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), usdplus.DEFAULT_ADMIN_ROLE()
            )
        );
        usdplus.setTransferRestrictor(_transferRestrictor);

        // admin can set transfer restrictor
        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit TransferRestrictorSet(_transferRestrictor);
        usdplus.setTransferRestrictor(_transferRestrictor);
        assertEq(address(usdplus.transferRestrictor()), address(_transferRestrictor));
    }

    function test_mint(uint256 amount) public {
        // non-minter cannot mint
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), usdplus.MINTER_ROLE()
            )
        );
        usdplus.mint(USER, amount);

        // grant minter role
        vm.startPrank(ADMIN);
        usdplus.grantRole(usdplus.MINTER_ROLE(), MINTER);
        vm.stopPrank();

        // minter can mint
        vm.prank(MINTER);
        usdplus.mint(USER, amount);
        assertEq(usdplus.balanceOf(USER), amount);
    }

    function test_burn(uint256 amount) public {
        // mint USD+ to user for testing
        vm.startPrank(ADMIN);
        usdplus.grantRole(usdplus.MINTER_ROLE(), MINTER);
        vm.stopPrank();

        vm.prank(MINTER);
        usdplus.mint(USER, amount);

        // non-burner cannot burn
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, USER, usdplus.BURNER_ROLE()
            )
        );
        vm.prank(USER);
        usdplus.burn(amount);

        // grant burner role
        vm.startPrank(ADMIN);
        usdplus.grantRole(usdplus.BURNER_ROLE(), USER);
        vm.stopPrank();

        // burner can burn
        vm.prank(USER);
        usdplus.burn(amount);
        assertEq(usdplus.balanceOf(USER), 0);
    }

    function test_burnFrom(uint256 amount) public {
        // mint USD+ to user for testing
        vm.startPrank(ADMIN);
        usdplus.grantRole(usdplus.MINTER_ROLE(), MINTER);
        vm.stopPrank();

        vm.prank(MINTER);
        usdplus.mint(USER, amount);

        // user approves burner
        vm.prank(USER);
        usdplus.approve(address(BURNER), amount);

        // non-burner cannot burn
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(BURNER), usdplus.BURNER_ROLE()
            )
        );
        vm.prank(address(BURNER));
        usdplus.burnFrom(USER, amount);

        // grant burner role
        vm.startPrank(ADMIN);
        usdplus.grantRole(usdplus.BURNER_ROLE(), address(BURNER));
        vm.stopPrank();

        // burner can burn
        vm.prank(address(BURNER));
        usdplus.burnFrom(USER, amount);
        assertEq(usdplus.balanceOf(USER), 0);
    }

    function test_transferReverts(address to, uint256 amount) public {
        vm.assume(to != address(0));

        // mint USD+ to user for testing
        vm.startPrank(ADMIN);
        usdplus.grantRole(usdplus.MINTER_ROLE(), MINTER);
        vm.stopPrank();

        vm.prank(MINTER);
        usdplus.mint(USER, amount);

        // restrict from
        vm.prank(ADMIN);
        transferRestrictor.restrict(USER);
        assertEq(usdplus.isBlacklisted(USER), true);

        vm.expectRevert(TransferRestrictor.AccountRestricted.selector);
        vm.prank(USER);
        usdplus.transfer(to, amount);

        // restrict to
        vm.startPrank(ADMIN);
        transferRestrictor.unrestrict(USER);
        transferRestrictor.restrict(to);
        vm.stopPrank();
        assertEq(usdplus.isBlacklisted(to), true);

        vm.expectRevert(TransferRestrictor.AccountRestricted.selector);
        vm.prank(USER);
        usdplus.transfer(to, amount);

        // remove restrictor
        vm.prank(ADMIN);
        usdplus.setTransferRestrictor(TransferRestrictor(address(0)));
        assertEq(usdplus.isBlacklisted(to), false);

        // transfer succeeds
        vm.prank(USER);
        usdplus.transfer(to, amount);
    }
}
