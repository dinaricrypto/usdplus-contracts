// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {TransferRestrictor} from "../src/TransferRestrictor.sol";
import {UsdPlusPlus} from "../src/UsdPlusPlus.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract UsdPlusPlusTest is Test {
    event LockDurationSet(uint48 duration);

    TransferRestrictor transferRestrictor;
    UsdPlus usdplus;
    UsdPlusPlus usdplusplus;

    address public constant ADMIN = address(0x1234);
    address public constant USER = address(0x1235);

    function setUp() public {
        transferRestrictor = new TransferRestrictor(address(this));
        usdplus = new UsdPlus(address(this), transferRestrictor, address(this));
        usdplusplus = new UsdPlusPlus(usdplus, ADMIN);

        // mint USD+ to user for testing
        usdplus.grantRole(usdplus.MINTER_ROLE(), address(this));
        usdplus.mint(address(USER), 100 ether);
        usdplus.mint(address(this), 100 ether);

        // seed USD++ with USD+
        usdplus.approve(address(usdplusplus), 100 ether);
        usdplusplus.deposit(100 ether, address(this));
    }

    function test_deploymentConfig() public {
        assertEq(usdplusplus.lockDuration(), 30 days);
        assertEq(usdplusplus.decimals(), 18);
    }

    function test_setLockDuration(uint48 duration) public {
        // non-admin cannot set lock duration
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        usdplusplus.setLockDuration(duration);

        // admin can set lock duration
        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit LockDurationSet(duration);
        usdplusplus.setLockDuration(duration);
        assertEq(usdplusplus.lockDuration(), duration);
    }

    function test_postMintLocks() public {
        // TODO: multiple locks
        // TODO: fuzz
        // TODO: fetch schedule
        // TODO: manual lock refresh

        // deposit USD+ for USD++
        vm.startPrank(USER);
        usdplus.approve(address(usdplusplus), 100 ether);
        usdplusplus.deposit(100 ether, USER);
        vm.stopPrank();
        assertEq(usdplusplus.sharesLocked(address(USER)), 100 ether);

        // yield 1%
        usdplus.mint(address(usdplusplus), 2 ether);
        assertEq(usdplusplus.convertToAssets(usdplusplus.totalSupply()), 202 ether - 1);

        // user can redeem now for original value
        vm.prank(USER);
        usdplusplus.redeem(50 ether, USER, USER);
        assertEq(usdplus.balanceOf(address(USER)), 50 ether);
        assertEq(usdplusplus.sharesLocked(address(USER)), 50 ether);

        // move forward 30 days
        vm.warp(block.timestamp + 30 days);

        // user can redeem after lock duration for yield
        vm.prank(USER);
        usdplusplus.redeem(50 ether, USER, USER);
        assertLt(usdplus.balanceOf(address(USER)), 100 ether + 1 ether - 1);
        assertEq(usdplusplus.sharesLocked(address(USER)), 0);
    }

    function test_transferReverts(address to, uint104 amount) public {
        vm.assume(to != address(0));

        usdplus.mint(USER, amount);

        vm.startPrank(USER);
        usdplus.approve(address(usdplusplus), amount);
        usdplusplus.deposit(amount, USER);
        vm.stopPrank();
        uint256 usdplusplusBalance = usdplusplus.balanceOf(USER);

        // restrict from
        transferRestrictor.restrict(USER);
        assertEq(usdplusplus.isBlacklisted(USER), true);

        vm.expectRevert(TransferRestrictor.AccountRestricted.selector);
        vm.prank(USER);
        usdplusplus.transfer(to, usdplusplusBalance);

        // restrict to
        transferRestrictor.unrestrict(USER);
        transferRestrictor.restrict(to);
        assertEq(usdplusplus.isBlacklisted(to), true);

        vm.expectRevert(TransferRestrictor.AccountRestricted.selector);
        vm.prank(USER);
        usdplusplus.transfer(to, usdplusplusBalance);

        // remove restrictor
        usdplus.setTransferRestrictor(TransferRestrictor(address(0)));
        assertEq(usdplusplus.isBlacklisted(to), false);

        // move forward 30 days
        vm.warp(block.timestamp + 30 days);

        // transfer succeeds
        vm.prank(USER);
        usdplusplus.transfer(to, usdplusplusBalance);
    }
}
