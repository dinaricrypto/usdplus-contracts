// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {UsdPlus} from "../../src/UsdPlus.sol";
import {TransferRestrictor} from "../../src/TransferRestrictor.sol";
import "../../src/bridge/CCIPWaypoint.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {CCIPRouterMock} from "../../src/mocks/CCIPRouterMock.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";

contract CCIPWaypointTest is Test {
    event RouterSet(address indexed router);
    event ApprovedSenderSet(uint64 indexed sourceChainSelector, address indexed sourceChainWaypoint);
    event ApprovedReceiverSet(uint64 indexed destinationChainSelector, address indexed destinationChainWaypoint);
    event Sent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address indexed destinationChainWaypoint,
        address to,
        uint256 amount,
        uint256 fee
    );
    event Received(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        address indexed sourceChainWaypoint,
        address to,
        uint256 amount
    );

    TransferRestrictor transferRestrictor;
    UsdPlus usdplus;
    CCIPWaypoint waypoint;
    ERC20Mock paymentToken;
    CCIPRouterMock router;

    address public constant ADMIN = address(0x1234);
    address public constant TREASURY = address(0x1235);
    address public constant USER = address(0x1238);
    address public constant OTHER = address(0x1239);
    address public constant UPGRADER = address(0x1237);

    function setUp() public {
        TransferRestrictor transferRestrictorImpl = new TransferRestrictor();
        transferRestrictor = TransferRestrictor(
            address(
                new ERC1967Proxy(
                    address(transferRestrictorImpl), abi.encodeCall(TransferRestrictor.initialize, (ADMIN, UPGRADER))
                )
            )
        );
        UsdPlus usdplusImpl = new UsdPlus();
        usdplus = UsdPlus(
            address(
                new ERC1967Proxy(
                    address(usdplusImpl),
                    abi.encodeCall(UsdPlus.initialize, (TREASURY, transferRestrictor, ADMIN, UPGRADER))
                )
            )
        );
        router = new CCIPRouterMock();
        CCIPWaypoint waypointImpl = new CCIPWaypoint();
        waypoint = CCIPWaypoint(
            address(
                new ERC1967Proxy(
                    address(waypointImpl),
                    abi.encodeCall(CCIPWaypoint.initialize, (address(usdplus), address(router), ADMIN, UPGRADER))
                )
            )
        );

        paymentToken = new ERC20Mock();
        paymentToken.mint(USER, type(uint256).max);

        vm.startPrank(ADMIN);
        usdplus.setIssuerLimits(ADMIN, type(uint256).max, 0);
        usdplus.mint(USER, type(uint256).max);

        // config waypoint
        waypoint.setApprovedSender(uint64(block.chainid), address(waypoint));
        waypoint.setApprovedReceiver(uint64(block.chainid), address(waypoint));

        // config router (would be pool in practice)
        usdplus.setIssuerLimits(address(router), type(uint256).max, type(uint256).max);
        vm.stopPrank();
    }

    function test_initialization() public {
        assertEq(address(waypoint.getRouter()), address(router));
    }

    function test_setRouterZeroReverts() public {
        vm.expectRevert(abi.encodeWithSelector(CCIPReceiver.InvalidRouter.selector, (address(0))));
        vm.prank(ADMIN);
        waypoint.setRouter(address(0));
    }

    function test_setRouter(address account) public {
        vm.assume(account != address(0));

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), waypoint.DEFAULT_ADMIN_ROLE()
            )
        );
        waypoint.setRouter(account);

        vm.expectEmit(true, true, true, true);
        emit RouterSet(account);
        vm.prank(ADMIN);
        waypoint.setRouter(account);
        assertEq(address(waypoint.getRouter()), account);
    }

    function test_setApprovedSender(uint64 chain, address account) public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), waypoint.DEFAULT_ADMIN_ROLE()
            )
        );
        waypoint.setApprovedSender(chain, account);

        vm.expectEmit(true, true, true, true);
        emit ApprovedSenderSet(chain, account);
        vm.prank(ADMIN);
        waypoint.setApprovedSender(chain, account);
        assertEq(waypoint.getApprovedSender(chain), account);
    }

    function test_setApprovedReceiver(uint64 chain, address account) public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), waypoint.DEFAULT_ADMIN_ROLE()
            )
        );
        waypoint.setApprovedReceiver(chain, account);

        vm.expectEmit(true, true, true, true);
        emit ApprovedReceiverSet(chain, account);
        vm.prank(ADMIN);
        waypoint.setApprovedReceiver(chain, account);
        assertEq(waypoint.getApprovedReceiver(chain), account);
    }

    function test_pause() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), waypoint.DEFAULT_ADMIN_ROLE()
            )
        );
        waypoint.pause();

        vm.prank(ADMIN);
        waypoint.pause();
        assertTrue(waypoint.paused());

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), waypoint.DEFAULT_ADMIN_ROLE()
            )
        );
        waypoint.unpause();

        vm.prank(ADMIN);
        waypoint.unpause();
        assertFalse(waypoint.paused());
    }

    function test_sendUsdPlusAndReceive(uint256 amount) public {
        vm.assume(amount > 0);

        uint256 fee = waypoint.getFee(uint64(block.chainid), address(waypoint), OTHER, amount);
        vm.deal(USER, fee);

        vm.prank(USER);
        usdplus.approve(address(waypoint), amount);

        // user sends usdplus to other
        uint256 userBalanceBefore = usdplus.balanceOf(USER);
        uint256 otherBalanceBefore = usdplus.balanceOf(OTHER);
        vm.prank(USER);
        waypoint.sendUsdPlus{value: fee}(uint64(block.chainid), OTHER, amount);
        assertEq(usdplus.balanceOf(USER), userBalanceBefore - amount);
        assertEq(usdplus.balanceOf(OTHER), otherBalanceBefore + amount);
    }

    function test_rescue(uint256 amount) public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), waypoint.DEFAULT_ADMIN_ROLE()
            )
        );
        waypoint.rescue(address(this), address(0), amount);

        vm.deal(address(waypoint), amount);

        vm.prank(ADMIN);
        waypoint.rescue(ADMIN, address(0), amount);
        assertEq(ADMIN.balance, amount);
    }

    function test_rescueToken(uint256 amount) public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), waypoint.DEFAULT_ADMIN_ROLE()
            )
        );
        waypoint.rescue(address(this), address(usdplus), amount);

        vm.prank(USER);
        usdplus.transfer(address(waypoint), amount);

        vm.prank(ADMIN);
        waypoint.rescue(ADMIN, address(usdplus), amount);
        assertEq(usdplus.balanceOf(ADMIN), amount);
    }
}
