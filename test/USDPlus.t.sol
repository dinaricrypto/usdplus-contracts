// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {TransferRestrictor, ITransferRestrictor} from "../src/TransferRestrictor.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC7281Min} from "../src/ERC7281/IERC7281Min.sol";

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
    address public constant BRIDGE = address(0x1239);

    function setUp() public {
        transferRestrictor = new TransferRestrictor(ADMIN);
        UsdPlus usdplusImpl = new UsdPlus();
        usdplus = UsdPlus(
            address(
                new ERC1967Proxy(
                    address(usdplusImpl), abi.encodeCall(UsdPlus.initialize, (TREASURY, transferRestrictor, ADMIN))
                )
            )
        );

        vm.startPrank(ADMIN);
        usdplus.setIssuerLimits(MINTER, type(uint256).max, 0);
        usdplus.setIssuerLimits(BURNER, 0, type(uint256).max);
        usdplus.setIssuerLimits(BRIDGE, 100 ether, 100 ether);
        vm.stopPrank();
    }

    function test_treasury(address treasury) public {
        // non-admin cannot set treasury
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
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
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        usdplus.setTransferRestrictor(_transferRestrictor);

        // admin can set transfer restrictor
        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit TransferRestrictorSet(_transferRestrictor);
        usdplus.setTransferRestrictor(_transferRestrictor);
        assertEq(address(usdplus.transferRestrictor()), address(_transferRestrictor));
    }

    function test_mint(uint256 amount) public {
        vm.assume(amount > 0);

        // non-minter cannot mint
        vm.expectRevert(IERC7281Min.ERC7281_LimitExceeded.selector);
        usdplus.mint(USER, amount);

        // minter can mint
        vm.prank(MINTER);
        usdplus.mint(USER, amount);
        assertEq(usdplus.balanceOf(USER), amount);
        assertEq(usdplus.mintingMaxLimitOf(MINTER), type(uint256).max);
        assertEq(usdplus.burningMaxLimitOf(MINTER), 0);
        assertEq(usdplus.mintingCurrentLimitOf(MINTER), type(uint256).max);
        assertEq(usdplus.burningCurrentLimitOf(MINTER), 0);
    }

    function test_burn(uint256 amount) public {
        vm.assume(amount > 0);

        // mint USD+ to user for testing
        vm.prank(MINTER);
        usdplus.mint(BURNER, amount);

        // non-burner cannot burn
        vm.expectRevert(IERC7281Min.ERC7281_LimitExceeded.selector);
        vm.prank(USER);
        usdplus.burn(amount);

        // burner can burn
        vm.prank(BURNER);
        usdplus.burn(amount);
        assertEq(usdplus.balanceOf(BURNER), 0);
        assertEq(usdplus.mintingMaxLimitOf(BURNER), 0);
        assertEq(usdplus.burningMaxLimitOf(BURNER), type(uint256).max);
        assertEq(usdplus.mintingCurrentLimitOf(BURNER), 0);
        assertEq(usdplus.burningCurrentLimitOf(BURNER), type(uint256).max);
    }

    function test_burnFrom(uint256 amount) public {
        vm.assume(amount > 0);

        // mint USD+ to user for testing
        vm.prank(MINTER);
        usdplus.mint(USER, amount);

        // user approves burner
        vm.prank(USER);
        usdplus.approve(BURNER, amount);

        // non-burner cannot burn
        vm.startPrank(USER);
        usdplus.approve(USER, amount);
        vm.expectRevert(IERC7281Min.ERC7281_LimitExceeded.selector);
        usdplus.burnFrom(USER, amount);
        vm.stopPrank();

        // burner can burn
        vm.prank(BURNER);
        usdplus.burnFrom(USER, amount);
        assertEq(usdplus.balanceOf(USER), 0);
        assertEq(usdplus.mintingMaxLimitOf(BURNER), 0);
        assertEq(usdplus.burningMaxLimitOf(BURNER), type(uint256).max);
        assertEq(usdplus.mintingCurrentLimitOf(BURNER), 0);
        assertEq(usdplus.burningCurrentLimitOf(BURNER), type(uint256).max);
    }

    function test_transferReverts(address to, uint256 amount) public {
        vm.assume(to != address(0));

        // mint USD+ to user for testing
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

    /// ------------------ ERC7281 ------------------

    function test_erc7281(uint256 amount) public {
        // mint USD+ to user for testing
        vm.prank(MINTER);
        usdplus.mint(USER, amount);

        // user approves bridge
        vm.prank(USER);
        usdplus.approve(BRIDGE, amount);

        if (amount > 100 ether) {
            vm.expectRevert(IERC7281Min.ERC7281_LimitExceeded.selector);
            vm.prank(BRIDGE);
            usdplus.burnFrom(USER, amount);
        } else {
            // circular bridging
            vm.startPrank(BRIDGE);
            usdplus.burnFrom(USER, amount);
            usdplus.mint(USER, amount);
            vm.stopPrank();
            assertEq(usdplus.balanceOf(USER), amount);
            assertEq(usdplus.mintingMaxLimitOf(BRIDGE), 100 ether);
            assertEq(usdplus.burningMaxLimitOf(BRIDGE), 100 ether);
            assertEq(usdplus.mintingCurrentLimitOf(BRIDGE), 100 ether - amount);
            assertEq(usdplus.burningCurrentLimitOf(BRIDGE), 100 ether - amount);

            // adjust limts after bridging
            vm.prank(ADMIN);
            usdplus.setIssuerLimits(BRIDGE, 200 ether, 50 ether);
            assertEq(usdplus.mintingMaxLimitOf(BRIDGE), 200 ether);
            assertEq(usdplus.burningMaxLimitOf(BRIDGE), 50 ether);
            assertEq(usdplus.mintingCurrentLimitOf(BRIDGE), 200 ether - amount);
            assertEq(usdplus.burningCurrentLimitOf(BRIDGE), amount > 50 ether ? 0 : 50 ether - amount);
        }
    }
}
