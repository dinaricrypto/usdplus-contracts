// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {TransferRestrictor} from "../src/TransferRestrictor.sol";
import {StakedUsdPlus} from "../src/StakedUsdPlus.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract StakedUsdPlusTest is Test {
    event LockDurationSet(uint48 duration);

    TransferRestrictor transferRestrictor;
    UsdPlus usdplus;
    StakedUsdPlus stakedusdplus;

    address public constant ADMIN = address(0x1234);
    address public constant USER = address(0x1235);

    function setUp() public {
        transferRestrictor = new TransferRestrictor(address(this));
        UsdPlus usdplusImpl = new UsdPlus();
        usdplus = UsdPlus(
            address(
                new ERC1967Proxy(address(usdplusImpl), abi.encodeCall(UsdPlus.initialize, (address(this), transferRestrictor, address(this))))
            )
        );
        StakedUsdPlus stakedusdplusImpl = new StakedUsdPlus();
        stakedusdplus = StakedUsdPlus(
            address(
                new ERC1967Proxy(address(stakedusdplusImpl), abi.encodeCall(StakedUsdPlus.initialize, (usdplus, ADMIN)))
            )
        );

        usdplus.grantRole(usdplus.MINTER_ROLE(), address(this));
    }

    function test_deploymentConfig() public {
        assertEq(stakedusdplus.lockDuration(), 30 days);
        assertEq(stakedusdplus.decimals(), 6);
    }

    function test_setLockDuration(uint48 duration) public {
        // non-admin cannot set lock duration
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        stakedusdplus.setLockDuration(duration);

        // admin can set lock duration
        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit LockDurationSet(duration);
        stakedusdplus.setLockDuration(duration);
        assertEq(stakedusdplus.lockDuration(), duration);
    }

    function test_mintLockZeroReverts() public {
        vm.expectRevert(StakedUsdPlus.ZeroValue.selector);
        vm.prank(USER);
        stakedusdplus.deposit(0, USER);
    }

    function test_mintLocks(uint104 amount1, uint104 amount2) public {
        vm.assume(amount1 > 0 && amount2 > 0);

        // mint USD+ to user for testing
        uint256 total = uint256(amount1) + amount2;
        usdplus.mint(USER, total);

        // deposit USD+ for stUSD+
        vm.startPrank(USER);
        usdplus.approve(address(stakedusdplus), amount1);
        stakedusdplus.deposit(amount1, USER);
        vm.stopPrank();
        assertEq(stakedusdplus.sharesLocked(address(USER)), amount1);

        // move forward 10 days
        vm.warp(block.timestamp + 10 days);

        // deposit more USD+ for stUSD+
        vm.startPrank(USER);
        usdplus.approve(address(stakedusdplus), amount2);
        stakedusdplus.deposit(amount2, USER);
        vm.stopPrank();
        assertEq(stakedusdplus.sharesLocked(address(USER)), total);

        StakedUsdPlus.Lock[] memory lockSchedule = stakedusdplus.getLockSchedule(address(USER));
        assertEq(lockSchedule.length, 2);
        assertEq(lockSchedule[0].shares, amount1);
        assertEq(lockSchedule[1].shares, amount2);

        // yield 1%
        uint256 yield = total / 100;
        usdplus.mint(address(stakedusdplus), yield);
        assertEq(stakedusdplus.convertToAssets(stakedusdplus.totalSupply()), total + (yield > 0 ? yield - 1 : 0));

        // move forward 20 days
        vm.warp(block.timestamp + 20 days);

        // refesh stale lock totals
        assertEq(stakedusdplus.sharesLocked(address(USER)), total);
        stakedusdplus.refreshLocks(address(USER));
        assertEq(stakedusdplus.sharesLocked(address(USER)), amount2);

        // redeem USD+ from stUSD+, early exit loses yield
        vm.prank(USER);
        stakedusdplus.redeem(total, USER, USER);
        assertGe(usdplus.balanceOf(address(USER)), total);
        assertEq(stakedusdplus.sharesLocked(address(USER)), 0);
    }

    function test_transferReverts(address to, uint104 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0);

        usdplus.mint(USER, amount);

        vm.startPrank(USER);
        usdplus.approve(address(stakedusdplus), amount);
        stakedusdplus.deposit(amount, USER);
        vm.stopPrank();
        uint256 stakedusdplusBalance = stakedusdplus.balanceOf(USER);

        // restrict from
        transferRestrictor.restrict(USER);
        assertEq(stakedusdplus.isBlacklisted(USER), true);

        vm.expectRevert(TransferRestrictor.AccountRestricted.selector);
        vm.prank(USER);
        stakedusdplus.transfer(to, stakedusdplusBalance);

        // restrict to
        transferRestrictor.unrestrict(USER);
        transferRestrictor.restrict(to);
        assertEq(stakedusdplus.isBlacklisted(to), true);

        vm.expectRevert(TransferRestrictor.AccountRestricted.selector);
        vm.prank(USER);
        stakedusdplus.transfer(to, stakedusdplusBalance);

        // remove restrictor
        usdplus.setTransferRestrictor(TransferRestrictor(address(0)));
        assertEq(stakedusdplus.isBlacklisted(to), false);

        // move forward 30 days
        vm.warp(block.timestamp + 30 days);

        // transfer succeeds
        vm.prank(USER);
        stakedusdplus.transfer(to, stakedusdplusBalance);
    }
}
