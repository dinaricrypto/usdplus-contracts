// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import {UsdPlus} from "../../src/UsdPlus.sol";
import {StakedUsdPlus} from "../../src/StakedUsdPlus.sol";
import {TransferRestrictor} from "../../src/TransferRestrictor.sol";
import "../../src/bridge/CCIPWaypoint.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {CCIPRouterMock} from "../../src/mocks/CCIPRouterMock.sol";

contract CCIPWaypointTest is Test {
    event ApprovedSenderSet(uint64 indexed sourceChainSelector, address indexed sourceChainWaypoint);
    event ApprovedReceiverSet(uint64 indexed destinationChainSelector, address indexed destinationChainWaypoint);
    event Sent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address indexed destinationChainWaypoint,
        address to,
        uint256 amount,
        bool stake,
        uint256 fee
    );
    event Received(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        address indexed sourceChainWaypoint,
        address to,
        uint256 amount,
        bool stake
    );

    TransferRestrictor transferRestrictor;
    UsdPlus usdplus;
    StakedUsdPlus stakedUsdplus;
    CCIPWaypoint waypoint;
    ERC20Mock paymentToken;
    CCIPRouterMock router;

    address public constant ADMIN = address(0x1234);
    address public constant TREASURY = address(0x1235);
    address public constant USER = address(0x1238);
    address public constant OTHER = address(0x1239);

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
        StakedUsdPlus stakedusdplusImpl = new StakedUsdPlus();
        stakedUsdplus = StakedUsdPlus(
            address(
                new ERC1967Proxy(address(stakedusdplusImpl), abi.encodeCall(StakedUsdPlus.initialize, (usdplus, ADMIN)))
            )
        );
        router = new CCIPRouterMock();
        CCIPWaypoint waypointImpl = new CCIPWaypoint();
        waypoint = CCIPWaypoint(
            address(
                new ERC1967Proxy(
                    address(waypointImpl),
                    abi.encodeCall(CCIPWaypoint.initialize, (usdplus, stakedUsdplus, address(router), ADMIN))
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

    function test_setApprovedSender(uint64 chain, address account) public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, (address(this))));
        waypoint.setApprovedSender(chain, account);

        vm.expectEmit(true, true, true, true);
        emit ApprovedSenderSet(chain, account);
        vm.prank(ADMIN);
        waypoint.setApprovedSender(chain, account);
        assertEq(waypoint.getApprovedSender(chain), account);
    }

    function test_setApprovedReceiver(uint64 chain, address account) public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, (address(this))));
        waypoint.setApprovedReceiver(chain, account);

        vm.expectEmit(true, true, true, true);
        emit ApprovedReceiverSet(chain, account);
        vm.prank(ADMIN);
        waypoint.setApprovedReceiver(chain, account);
        assertEq(waypoint.getApprovedReceiver(chain), account);
    }

    function test_pause() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, (address(this))));
        waypoint.pause();

        vm.prank(ADMIN);
        waypoint.pause();
        assertTrue(waypoint.paused());

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, (address(this))));
        waypoint.unpause();

        vm.prank(ADMIN);
        waypoint.unpause();
        assertFalse(waypoint.paused());
    }

    function test_sendUsdPlusAndReceive(uint256 amount) public {
        vm.assume(amount > 0);

        uint256 fee = waypoint.getFee(uint64(block.chainid), address(waypoint), OTHER, amount, false);
        vm.deal(USER, fee);

        vm.prank(USER);
        usdplus.approve(address(waypoint), amount);

        // user sends usdplus to other
        uint256 userBalanceBefore = usdplus.balanceOf(USER);
        uint256 otherBalanceBefore = usdplus.balanceOf(OTHER);
        vm.prank(USER);
        waypoint.sendUsdPlus{value: fee}(uint64(block.chainid), OTHER, amount, false);
        assertEq(usdplus.balanceOf(USER), userBalanceBefore - amount);
        assertEq(usdplus.balanceOf(OTHER), otherBalanceBefore + amount);
    }

    function test_sendUsdPlusAndStake(uint104 amount) public {
        vm.assume(amount > 0);
        // TODO: replace with maxDeposit check in waypoint
        vm.assume(amount < type(uint104).max);

        uint256 fee = waypoint.getFee(uint64(block.chainid), address(waypoint), OTHER, amount, true);
        vm.deal(USER, fee);

        vm.prank(USER);
        usdplus.approve(address(waypoint), amount);

        vm.expectRevert(CCIPWaypoint.StakingDisabled.selector);
        vm.prank(USER);
        waypoint.sendUsdPlus{value: fee}(uint64(block.chainid), OTHER, amount, true);

        vm.prank(ADMIN);
        waypoint.setStakingEnabled(uint64(block.chainid), true);

        // user sends usdplus to other and stakes
        uint256 userBalanceBefore = usdplus.balanceOf(USER);
        uint256 otherBalanceBefore = stakedUsdplus.balanceOf(OTHER);
        vm.prank(USER);
        waypoint.sendUsdPlus{value: fee}(uint64(block.chainid), OTHER, amount, true);
        assertEq(usdplus.balanceOf(USER), userBalanceBefore - amount);
        assertEq(stakedUsdplus.balanceOf(OTHER), otherBalanceBefore + amount);
    }

    function test_rescue(uint256 amount) public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, (address(this))));
        waypoint.rescue(address(this), address(0), amount);

        vm.deal(address(waypoint), amount);

        vm.prank(ADMIN);
        waypoint.rescue(ADMIN, address(0), amount);
        assertEq(ADMIN.balance, amount);
    }

    function test_rescueToken(uint256 amount) public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, (address(this))));
        waypoint.rescue(address(this), address(usdplus), amount);

        vm.prank(USER);
        usdplus.transfer(address(waypoint), amount);

        vm.prank(ADMIN);
        waypoint.rescue(ADMIN, address(usdplus), amount);
        assertEq(usdplus.balanceOf(ADMIN), amount);
    }
}
