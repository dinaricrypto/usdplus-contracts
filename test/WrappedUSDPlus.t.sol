// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {TransferRestrictor} from "../src/TransferRestrictor.sol";
import {WrappedUsdPlus} from "../src/WrappedUsdPlus.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC4626} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";

contract WrappedUsdPlusTest is Test {
    event LockDurationSet(uint48 duration);

    TransferRestrictor transferRestrictor;
    UsdPlus usdplus;
    WrappedUsdPlus wrappedUsdplus;

    address public constant ADMIN = address(0x1234);
    address public constant USER = address(0x1235);
    address public constant USER2 = address(0x1236);
    address public constant UPGRADER = address(0x1237);

    function setUp() public {
        TransferRestrictor transferRestrictorImpl = new TransferRestrictor();
        transferRestrictor = TransferRestrictor(
            address(
                new ERC1967Proxy(
                    address(transferRestrictorImpl),
                    abi.encodeCall(TransferRestrictor.initialize, (address(this), UPGRADER))
                )
            )
        );
        UsdPlus usdplusImpl = new UsdPlus();
        usdplus = UsdPlus(
            address(
                new ERC1967Proxy(
                    address(usdplusImpl),
                    abi.encodeCall(
                        UsdPlus.initialize, (address(this), transferRestrictor, address(this), UPGRADER)
                    )
                )
            )
        );
        WrappedUsdPlus wrappedUsdplusImpl = new WrappedUsdPlus();
        wrappedUsdplus = WrappedUsdPlus(
            address(
                new ERC1967Proxy(
                    address(wrappedUsdplusImpl),
                    abi.encodeCall(WrappedUsdPlus.initialize, (address(usdplus), ADMIN, UPGRADER))
                )
            )
        );

        usdplus.setIssuerLimits(address(this), type(uint256).max, 0);

        // mint large supply to user
        usdplus.mint(USER, type(uint128).max);

        // start testing with non-zero state
        vm.prank(USER);
        usdplus.transfer(address(this), 1.001 ether);

        usdplus.approve(address(wrappedUsdplus), 1 ether);
        wrappedUsdplus.deposit(1 ether, address(this));
        // add yield
        usdplus.transfer(address(wrappedUsdplus), 0.001 ether);
    }

    function test_deploymentConfig() public {
        assertEq(wrappedUsdplus.decimals(), 6);
    }

    function test_transferReverts(address to, uint104 amount) public {
        vm.assume(to != address(0));
        vm.assume(wrappedUsdplus.previewDeposit(amount) > 0);

        vm.startPrank(USER);
        usdplus.approve(address(wrappedUsdplus), amount);
        wrappedUsdplus.deposit(amount, USER);
        vm.stopPrank();
        uint256 wrappedUsdplusBalance = wrappedUsdplus.balanceOf(USER);

        // restrict from
        transferRestrictor.restrict(USER);
        assertEq(wrappedUsdplus.isBlacklisted(USER), true);

        vm.expectRevert(TransferRestrictor.AccountRestricted.selector);
        vm.prank(USER);
        wrappedUsdplus.transfer(to, wrappedUsdplusBalance);

        // restrict to
        transferRestrictor.unrestrict(USER);
        transferRestrictor.restrict(to);
        assertEq(wrappedUsdplus.isBlacklisted(to), true);

        vm.expectRevert(TransferRestrictor.AccountRestricted.selector);
        vm.prank(USER);
        wrappedUsdplus.transfer(to, wrappedUsdplusBalance);

        // remove restrictor
        usdplus.setTransferRestrictor(TransferRestrictor(address(0)));
        assertEq(wrappedUsdplus.isBlacklisted(to), false);

        // move forward 30 days
        vm.warp(block.timestamp + 30 days);

        // transfer succeeds
        vm.prank(USER);
        wrappedUsdplus.transfer(to, wrappedUsdplusBalance);
    }
}
