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

        // mint USD+ to user for testing
        usdplus.grantRole(usdplus.MINTER_ROLE(), address(this));
        usdplus.mint(address(USER), 100 ether);
        usdplus.mint(address(this), 100 ether);

        // seed stUSD+ with USD+
        usdplus.approve(address(stakedusdplus), 100 ether);
        stakedusdplus.deposit(100 ether, address(this));
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

    function test_postMintLocks() public {
        // TODO: multiple locks
        // TODO: fuzz
        // TODO: fetch schedule
        // TODO: manual lock refresh

        // deposit USD+ for stUSD+
        vm.startPrank(USER);
        usdplus.approve(address(stakedusdplus), 100 ether);
        stakedusdplus.deposit(100 ether, USER);
        vm.stopPrank();
        assertEq(stakedusdplus.sharesLocked(address(USER)), 100 ether);

        // yield 1%
        usdplus.mint(address(stakedusdplus), 2 ether);
        assertEq(stakedusdplus.convertToAssets(stakedusdplus.totalSupply()), 202 ether - 1);

        // user can redeem now for original value
        vm.prank(USER);
        stakedusdplus.redeem(50 ether, USER, USER);
        assertEq(usdplus.balanceOf(address(USER)), 50 ether);
        assertEq(stakedusdplus.sharesLocked(address(USER)), 50 ether);

        // move forward 30 days
        vm.warp(block.timestamp + 30 days);

        // user can redeem after lock duration for yield
        vm.prank(USER);
        stakedusdplus.redeem(50 ether, USER, USER);
        assertLt(usdplus.balanceOf(address(USER)), 100 ether + 1 ether - 1);
        assertEq(stakedusdplus.sharesLocked(address(USER)), 0);
    }

    function test_transferReverts(address to, uint104 amount) public {
        vm.assume(to != address(0));

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
