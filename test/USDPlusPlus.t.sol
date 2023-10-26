// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {UsdPlusPlus} from "../src/UsdPlusPlus.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract UsdPlusPlusTest is Test {
    event LockDurationSet(uint48 duration);

    UsdPlus usdplus;
    UsdPlusPlus usdplusplus;

    address public constant ADMIN = address(0x1234);
    address public constant USER = address(0x1235);

    function setUp() public {
        usdplus = new UsdPlus(address(this));
        usdplusplus = new UsdPlusPlus(usdplus, ADMIN);

        // mint USD+ to user for testing
        usdplus.grantRole(usdplus.MINTER_ROLE(), address(this));
        usdplus.mint(address(USER), 1000);
    }

    function test_setLockDuration() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        usdplusplus.setLockDuration(5 days);

        vm.prank(ADMIN);
        vm.expectEmit(true, true, true, true);
        emit LockDurationSet(5 days);
        usdplusplus.setLockDuration(5 days);
        assertEq(usdplusplus.lockDuration(), 5 days);
    }
}
