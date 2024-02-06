// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {TransferRestrictor} from "../src/TransferRestrictor.sol";
import {StakedUsdPlus} from "../src/StakedUsdPlus.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC4626} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";

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
                new ERC1967Proxy(
                    address(usdplusImpl),
                    abi.encodeCall(UsdPlus.initialize, (address(this), transferRestrictor, address(this)))
                )
            )
        );
        StakedUsdPlus stakedusdplusImpl = new StakedUsdPlus();
        stakedusdplus = StakedUsdPlus(
            address(
                new ERC1967Proxy(address(stakedusdplusImpl), abi.encodeCall(StakedUsdPlus.initialize, (usdplus, ADMIN)))
            )
        );

        usdplus.setIssuerLimits(address(this), type(uint256).max, 0);

        // mint large supply to user
        usdplus.mint(USER, type(uint128).max);

        // start testing with non-zero state
        vm.prank(USER);
        usdplus.transfer(address(this), 1.001 ether);

        usdplus.approve(address(stakedusdplus), 1 ether);
        stakedusdplus.deposit(1 ether, address(this));
        // add yield
        usdplus.transfer(address(stakedusdplus), 0.001 ether);
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

    function test_depositZeroReverts(uint8 amount) public {
        vm.assume(amount == 0 || stakedusdplus.previewDeposit(amount) == 0);

        vm.expectRevert(StakedUsdPlus.ZeroValue.selector);
        vm.prank(USER);
        stakedusdplus.deposit(amount, USER);
    }

    function test_depositLargeReverts(uint128 amount) public {
        vm.assume(stakedusdplus.previewDeposit(amount) > 0);
        vm.assume(amount <= usdplus.balanceOf(USER));

        uint256 max = stakedusdplus.maxDeposit(address(0));
        vm.startPrank(USER);
        usdplus.approve(address(stakedusdplus), amount);
        if (amount > max) {
            vm.expectRevert(abi.encodeWithSelector(ERC4626.ERC4626ExceededMaxDeposit.selector, USER, amount, max));
        }
        stakedusdplus.deposit(amount, USER);
        vm.stopPrank();
    }

    function test_mintZeroReverts(uint8 amount) public {
        vm.assume(amount == 0 || stakedusdplus.previewMint(amount) == 0);

        vm.expectRevert(StakedUsdPlus.ZeroValue.selector);
        vm.prank(USER);
        stakedusdplus.deposit(amount, USER);
    }

    function test_mintLargeReverts(uint128 amount) public {
        uint256 deposit = stakedusdplus.previewMint(amount);
        vm.assume(deposit > 0);
        vm.assume(amount <= usdplus.balanceOf(USER));

        uint256 max = stakedusdplus.maxMint(address(0));
        vm.startPrank(USER);
        usdplus.approve(address(stakedusdplus), deposit);
        if (amount > max) {
            vm.expectRevert(abi.encodeWithSelector(ERC4626.ERC4626ExceededMaxMint.selector, USER, amount, max));
        }
        stakedusdplus.mint(amount, USER);
        vm.stopPrank();
    }

    function test_refreshOldestLock() public {
        usdplus.mint(USER, 1000);

        vm.startPrank(USER);
        usdplus.approve(address(stakedusdplus), 1000);
        // TODO: test double entry
        // stakedusdplus.deposit(10, USER);
        uint256 intialtime = block.timestamp;
        for (uint256 i = 0; i < 10; i++) {
            stakedusdplus.deposit(10, USER);
            vm.warp(intialtime + 1 + i);
        }
        vm.stopPrank();

        // refresh oldest lock - not expired
        bool removed = stakedusdplus.refreshOldestLock(USER);
        assertFalse(removed);
        assertEq(stakedusdplus.getLockSchedule(address(USER)).length, 10);

        // refresh oldest lock - expired
        vm.warp(block.timestamp + 30 days);
        removed = stakedusdplus.refreshOldestLock(USER);
        assertTrue(removed);
        assertEq(stakedusdplus.getLockSchedule(address(USER)).length, 9);
    }

    function test_refreshManyLocks() public {
        uint256 n = 1000;
        usdplus.mint(USER, n * 10);

        vm.startPrank(USER);
        usdplus.approve(address(stakedusdplus), n * 10);
        // TODO: test double entry
        // stakedusdplus.deposit(10, USER);
        uint256 intialtime = block.timestamp;
        for (uint256 i = 0; i < n; i++) {
            stakedusdplus.deposit(10, USER);
            vm.warp(intialtime + 1 + i);
        }
        vm.stopPrank();

        // refresh locks - not expired
        stakedusdplus.refreshLocks(USER);
        assertEq(stakedusdplus.getLockSchedule(address(USER)).length, n);

        // refresh locks - expired
        vm.warp(block.timestamp + 30 days);
        stakedusdplus.refreshLocks(USER);
        assertEq(stakedusdplus.getLockSchedule(address(USER)).length, 0);
    }

    function test_mintLocks(uint104 amount1, uint104 amount2) public {
        vm.assume(stakedusdplus.previewDeposit(amount1) > 0);
        vm.assume(stakedusdplus.previewDeposit(amount2) > 0);
        uint256 total = uint256(amount1) + amount2;
        uint256 userBalance = usdplus.balanceOf(USER);
        vm.assume(total <= userBalance);

        // deposit USD+ for stUSD+
        vm.startPrank(USER);
        usdplus.approve(address(stakedusdplus), amount1);
        uint256 shares1 = stakedusdplus.deposit(amount1, USER);
        vm.stopPrank();
        assertEq(stakedusdplus.assetsLocked(address(USER)), amount1);
        assertEq(stakedusdplus.sharesLocked(address(USER)), shares1);

        // move forward 10 days
        vm.warp(block.timestamp + 10 days);

        // deposit more USD+ for stUSD+
        vm.startPrank(USER);
        usdplus.approve(address(stakedusdplus), amount2);
        uint256 shares2 = stakedusdplus.deposit(amount2, USER);
        vm.stopPrank();
        uint256 sharesTotal = shares1 + shares2;
        assertEq(stakedusdplus.assetsLocked(address(USER)), total);
        assertEq(stakedusdplus.sharesLocked(address(USER)), sharesTotal);

        StakedUsdPlus.Lock[] memory lockSchedule = stakedusdplus.getLockSchedule(address(USER));
        assertEq(lockSchedule.length, 2);
        assertEq(lockSchedule[0].assets, amount1);
        assertEq(lockSchedule[0].shares, shares1);
        assertEq(lockSchedule[1].assets, amount2);
        assertEq(lockSchedule[1].shares, shares2);

        // yield 1%
        uint256 yield = stakedusdplus.totalSupply() / 100;
        usdplus.mint(address(stakedusdplus), yield);
        // assertEq(stakedusdplus.convertToAssets(stakedusdplus.totalSupply()), total + (yield > 0 ? yield - 1 : 0));

        // move forward 20 days
        vm.warp(block.timestamp + 20 days);

        // refesh stale lock totals
        assertEq(stakedusdplus.assetsLocked(address(USER)), total);
        assertEq(stakedusdplus.sharesLocked(address(USER)), sharesTotal);
        stakedusdplus.refreshLocks(address(USER));
        assertEq(stakedusdplus.assetsLocked(address(USER)), amount2);
        assertEq(stakedusdplus.sharesLocked(address(USER)), shares2);

        // redeem USD+ from stUSD+, early exit loses yield
        vm.prank(USER);
        stakedusdplus.redeem(sharesTotal, USER, USER);
        assertGe(usdplus.balanceOf(address(USER)), userBalance - 1);
        assertEq(stakedusdplus.assetsLocked(address(USER)), 0);
        assertEq(stakedusdplus.sharesLocked(address(USER)), 0);
    }

    function test_transferReverts(address to, uint104 amount) public {
        vm.assume(to != address(0));
        vm.assume(stakedusdplus.previewDeposit(amount) > 0);

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
