// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {TransferRestrictor} from "../src/TransferRestrictor.sol";
import "../src/UsdPlusRedeemer.sol";
import {IUsdPlusRedeemer} from "../src/IUsdPlusRedeemer.sol";
import {Permit} from "../src/SelfPermit.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {SigUtils} from "./utils/SigUtils.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {IERC7281Min} from "../src/ERC7281/IERC7281Min.sol";
import {MockToken} from "./utils/mocks/MockToken.sol";

contract UsdPlusRedeemerTest is Test {
    event PaymentTokenOracleSet(IERC20 indexed paymentToken, AggregatorV3Interface oracle);
    event RequestCreated(
        uint256 indexed ticket,
        address indexed to,
        IERC20 paymentToken,
        uint256 paymentTokenAmount,
        uint256 usdplusAmount
    );
    event RequestCancelled(uint256 indexed ticket, address indexed to);
    event RequestFulfilled(
        uint256 indexed ticket,
        address indexed to,
        IERC20 paymentToken,
        uint256 paymentTokenAmount,
        uint256 usdplusAmount
    );
    event RequestBurned(uint256 indexed ticket, address indexed receiver, uint256 usdplusAmount);

    TransferRestrictor transferRestrictor;
    UsdPlus usdplus;
    UsdPlusRedeemer redeemer;
    MockToken paymentToken;
    SigUtils sigUtils;

    uint256 public userPrivateKey;

    address public ADMIN = address(0x1234);
    address public constant FULFILLER = address(0x1235);
    address public USER;
    address constant usdcPriceOracle = 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3;

    function setUp() public {
        userPrivateKey = 0x1236;
        USER = vm.addr(userPrivateKey);
        TransferRestrictor transferRestrictorImpl = new TransferRestrictor();
        transferRestrictor = TransferRestrictor(
            address(
                new ERC1967Proxy(
                    address(transferRestrictorImpl), abi.encodeCall(TransferRestrictor.initialize, (ADMIN))
                )
            )
        );
        UsdPlus usdplusImpl = new UsdPlus();
        usdplus = UsdPlus(
            address(
                new ERC1967Proxy(
                    address(usdplusImpl), abi.encodeCall(UsdPlus.initialize, (address(this), transferRestrictor, ADMIN))
                )
            )
        );
        UsdPlusRedeemer redeemerImpl = new UsdPlusRedeemer();
        redeemer = UsdPlusRedeemer(
            address(
                new ERC1967Proxy(
                    address(redeemerImpl), abi.encodeCall(UsdPlusRedeemer.initialize, (address(usdplus), ADMIN))
                )
            )
        );
        paymentToken = new MockToken("Money", "$");
        sigUtils = new SigUtils(usdplus.DOMAIN_SEPARATOR());

        vm.startPrank(ADMIN);
        usdplus.setIssuerLimits(address(this), type(uint256).max, 0);
        redeemer.grantRole(redeemer.FULFILLER_ROLE(), FULFILLER);
        vm.stopPrank();

        usdplus.mint(USER, type(uint256).max);
        paymentToken.mint(FULFILLER, type(uint256).max);
    }

    function test_initialization() public {
        assertEq(redeemer.usdplus(), address(usdplus));
        assertEq(redeemer.nextTicket(), 0);
    }

    function test_setPaymentTokenOracle(IERC20 token, address oracle) public {
        // non-admin cannot set payment token oracle
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), redeemer.DEFAULT_ADMIN_ROLE()
            )
        );
        redeemer.setPaymentTokenOracle(token, AggregatorV3Interface(oracle));

        // admin can set payment token oracle
        vm.expectEmit(true, true, true, true);
        emit PaymentTokenOracleSet(token, AggregatorV3Interface(oracle));
        vm.prank(ADMIN);
        redeemer.setPaymentTokenOracle(token, AggregatorV3Interface(oracle));
        assertEq(address(redeemer.paymentTokenOracle(token)), oracle);
    }

    function test_previewRedeem(uint256 amount) public {
        vm.assume(amount < type(uint256).max / 2);

        // payment token oracle not set
        vm.expectRevert(IUsdPlusRedeemer.PaymentTokenNotAccepted.selector);
        redeemer.previewRedeem(paymentToken, amount);

        vm.prank(ADMIN);
        redeemer.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        redeemer.previewRedeem(paymentToken, amount);
    }

    function test_previewWithdraw(uint256 amount) public {
        vm.assume(amount < type(uint256).max / 2);

        // payment token oracle not set
        vm.expectRevert(IUsdPlusRedeemer.PaymentTokenNotAccepted.selector);
        redeemer.previewWithdraw(paymentToken, amount);

        vm.prank(ADMIN);
        redeemer.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        redeemer.previewWithdraw(paymentToken, amount);
    }

    function test_requestWithdrawToZeroAddressReverts(uint256 amount) public {
        vm.expectRevert(UsdPlusRedeemer.ZeroAddress.selector);
        redeemer.requestWithdraw(paymentToken, amount, address(0), USER);
    }

    function test_requestWithdrawZeroAmountReverts() public {
        vm.expectRevert(UsdPlusRedeemer.ZeroAmount.selector);
        redeemer.requestWithdraw(paymentToken, 0, USER, USER);
    }

    function test_requestWithdraw(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max / 2);

        vm.startPrank(ADMIN);
        redeemer.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));
        // usdplus are burnt during request now
        usdplus.setIssuerLimits(address(redeemer), 0, type(uint256).max);
        vm.stopPrank();

        uint256 usdplusAmount = redeemer.previewWithdraw(paymentToken, amount);

        vm.prank(USER);
        usdplus.approve(address(redeemer), usdplusAmount);

        // reverts if withdrawal amount is 0
        if (usdplusAmount == 0) {
            vm.expectRevert(UsdPlusRedeemer.ZeroAmount.selector);
            redeemer.requestWithdraw(paymentToken, amount, USER, USER);
            return;
        }

        vm.expectEmit(true, true, true, true);
        emit RequestCreated(0, USER, paymentToken, amount, usdplusAmount);
        vm.prank(USER);
        uint256 ticket = redeemer.requestWithdraw(paymentToken, amount, USER, USER);

        IUsdPlusRedeemer.Request memory request = redeemer.requests(ticket);
        assertEq(request.paymentTokenAmount, amount);
        assertEq(request.usdplusAmount, usdplusAmount);
    }

    function test_requestToZeroAddressReverts(uint256 amount) public {
        vm.expectRevert(UsdPlusRedeemer.ZeroAddress.selector);
        redeemer.requestRedeem(paymentToken, amount, address(0), USER);
    }

    function test_requestZeroAmountReverts() public {
        vm.expectRevert(UsdPlusRedeemer.ZeroAmount.selector);
        redeemer.requestRedeem(paymentToken, 0, USER, USER);
    }

    function test_pause_unpause() public {
        // non-admin cannot pause
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), redeemer.DEFAULT_ADMIN_ROLE()
            )
        );
        redeemer.pause();

        // admin can pause
        vm.prank(ADMIN);
        redeemer.pause();
        assertEq(redeemer.paused(), true);

        // non-admin cannot unpause
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), redeemer.DEFAULT_ADMIN_ROLE()
            )
        );
        redeemer.unpause();

        vm.prank(ADMIN);
        redeemer.unpause();
        assertEq(redeemer.paused(), false);
    }

    function test_requestRedeem(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max / 2);

        vm.prank(ADMIN);
        redeemer.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        uint256 balanceBefore = usdplus.balanceOf(USER);

        vm.prank(USER);
        usdplus.approve(address(redeemer), amount);

        uint256 redemptionEstimate = redeemer.previewRedeem(paymentToken, amount);

        // reverts if redemption amount is 0
        if (redemptionEstimate == 0) {
            vm.expectRevert(UsdPlusRedeemer.ZeroAmount.selector);
            redeemer.requestRedeem(paymentToken, amount, USER, USER);
            return;
        }

        // revert with limit exceed
        vm.prank(USER);
        vm.expectRevert(IERC7281Min.ERC7281_LimitExceeded.selector);
        uint256 ticket = redeemer.requestRedeem(paymentToken, amount, USER, USER);

        // set limit
        vm.prank(ADMIN);
        usdplus.setIssuerLimits(address(redeemer), 0, type(uint256).max);

        // Test unauthorized redeemer scenario
        address ATTACKER = address(0xdead);
        vm.prank(ATTACKER);
        vm.expectRevert(IUsdPlusRedeemer.UnauthorizedRedeemer.selector);
        redeemer.requestRedeem(paymentToken, amount, USER, USER);

        // Test successful case
        vm.expectEmit(true, true, true, true);
        emit RequestCreated(0, USER, paymentToken, redemptionEstimate, amount);
        vm.prank(USER);
        ticket = redeemer.requestRedeem(paymentToken, amount, USER, USER);

        assertEq(usdplus.balanceOf(address(redeemer)), 0);
        assertEq(balanceBefore - amount, usdplus.balanceOf(USER));

        IUsdPlusRedeemer.Request memory request = redeemer.requests(ticket);
        assertEq(request.paymentTokenAmount, redemptionEstimate);
    }

    // Add a separate test for unauthorized redemption
    function test_requestRedeem_UnauthorizedRedeemer() public {
        uint256 amount = 1000e6; // 1000 USDC
        address ATTACKER = address(0xdead);

        vm.prank(ADMIN);
        redeemer.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        vm.prank(USER);
        usdplus.approve(address(redeemer), amount);

        // Try to redeem on behalf of USER without authorization
        vm.prank(ATTACKER);
        vm.expectRevert(IUsdPlusRedeemer.UnauthorizedRedeemer.selector);
        redeemer.requestRedeem(paymentToken, amount, USER, USER);
    }

    function test_permitRequestRedeem(uint256 amount) public {
        vm.assume(amount > 1 && amount < type(uint256).max / 2);

        vm.startPrank(ADMIN);
        redeemer.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));
        usdplus.setIssuerLimits(address(redeemer), 0, type(uint256).max);
        vm.stopPrank();

        SigUtils.Permit memory sigPermit = SigUtils.Permit({
            owner: USER,
            spender: address(redeemer),
            value: amount,
            nonce: 0,
            deadline: block.timestamp + 30 days
        });
        bytes32 digest = sigUtils.getTypedDataHash(sigPermit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

        Permit memory permit = Permit({
            owner: sigPermit.owner,
            spender: sigPermit.spender,
            value: sigPermit.value,
            nonce: sigPermit.nonce,
            deadline: sigPermit.deadline
        });

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeCall(
            redeemer.selfPermit, (address(usdplus), permit.owner, permit.value, permit.deadline, v + 1, r, s)
        );
        calls[1] = abi.encodeCall(redeemer.requestRedeem, (paymentToken, amount, USER, USER));

        // Test invalid signature reverts
        vm.prank(USER);
        vm.expectRevert();
        redeemer.multicall(calls);

        // Test unauthorized caller reverts
        calls[0] = abi.encodeCall(
            redeemer.selfPermit, (address(usdplus), permit.owner, permit.value, permit.deadline, v, r, s)
        );
        vm.prank(ADMIN);
        vm.expectRevert(IUsdPlusRedeemer.UnauthorizedRedeemer.selector);
        redeemer.multicall(calls);

        // Test successful case with proper owner
        vm.prank(USER);
        bytes[] memory results = redeemer.multicall(calls);
        uint256 ticket = abi.decode(results[1], (uint256));

        IUsdPlusRedeemer.Request memory request = redeemer.requests(ticket);
        assertEq(request.owner, USER);
        uint256 expectedPaymentAmount = redeemer.previewRedeem(paymentToken, amount);
        assertEq(request.paymentTokenAmount, expectedPaymentAmount);
    }

    function test_fulfillInvalidTicketReverts(uint256 ticket) public {
        vm.expectRevert(IUsdPlusRedeemer.InvalidTicket.selector);
        vm.prank(FULFILLER);
        redeemer.fulfill(ticket);
    }

    function test_fulfill(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max / 2);

        vm.prank(ADMIN);
        redeemer.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        uint256 redemptionEstimate = redeemer.previewRedeem(paymentToken, amount);
        vm.assume(redemptionEstimate > 0);

        vm.startPrank(USER);
        usdplus.approve(address(redeemer), amount);
        vm.expectRevert(IERC7281Min.ERC7281_LimitExceeded.selector);
        uint256 ticket = redeemer.requestRedeem(paymentToken, amount, USER, USER);
        vm.stopPrank();

        vm.prank(ADMIN);
        usdplus.setIssuerLimits(address(redeemer), 0, type(uint256).max);

        vm.startPrank(USER);
        usdplus.approve(address(redeemer), amount);
        ticket = redeemer.requestRedeem(paymentToken, amount, USER, USER);
        vm.stopPrank();

        // not fulfiller
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), redeemer.FULFILLER_ROLE()
            )
        );
        redeemer.fulfill(ticket);

        vm.prank(USER);
        usdplus.approve(address(redeemer), amount);

        vm.startPrank(FULFILLER);
        paymentToken.approve(address(redeemer), redemptionEstimate);

        vm.expectEmit(true, true, true, true);
        emit RequestFulfilled(ticket, USER, paymentToken, redemptionEstimate, amount);
        redeemer.fulfill(ticket);
        vm.stopPrank();
        assertEq(paymentToken.balanceOf(USER), redemptionEstimate);
        assertEq(usdplus.balanceOf(address(redeemer)), 0);
    }

    function test_cancelInvalidTicketReverts(uint256 ticket) public {
        vm.expectRevert(IUsdPlusRedeemer.InvalidTicket.selector);
        vm.prank(FULFILLER);
        redeemer.cancel(ticket);
    }

    function test_cancel(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max / 2);

        vm.prank(ADMIN);
        redeemer.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        uint256 redemptionEstimate = redeemer.previewRedeem(paymentToken, amount);
        vm.assume(redemptionEstimate > 0);

        uint256 balanceBefore = usdplus.balanceOf(USER);

        vm.prank(ADMIN);
        usdplus.setIssuerLimits(address(redeemer), type(uint256).max, type(uint256).max);

        vm.startPrank(USER);
        usdplus.approve(address(redeemer), amount);
        uint256 ticket = redeemer.requestRedeem(paymentToken, amount, USER, USER);
        vm.stopPrank();

        assertEq(balanceBefore - amount, usdplus.balanceOf(USER));
        assertEq(usdplus.balanceOf(address(redeemer)), 0);

        // not fulfiller
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), redeemer.FULFILLER_ROLE()
            )
        );
        redeemer.cancel(ticket);

        vm.expectEmit(true, true, true, true);
        emit RequestCancelled(ticket, USER);
        vm.prank(FULFILLER);
        redeemer.cancel(ticket);

        assertEq(usdplus.balanceOf(USER), balanceBefore);
    }

    function test_burnRequest(uint256 amount) public {
        vm.assume(amount > 1 && amount < type(uint256).max / 2);

        vm.startPrank(ADMIN);
        redeemer.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));
        usdplus.setIssuerLimits(address(redeemer), 0, type(uint256).max);
        vm.stopPrank();

        vm.startPrank(USER);
        usdplus.approve(address(redeemer), amount);
        uint256 ticket = redeemer.requestRedeem(paymentToken, amount, USER, USER);
        vm.stopPrank();

        // not fulfiller
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), redeemer.FULFILLER_ROLE()
            )
        );
        redeemer.burnRequest(ticket);

        vm.expectEmit(true, true, true, true);
        emit RequestBurned(ticket, USER, amount);
        vm.prank(FULFILLER);
        redeemer.burnRequest(ticket);
        assertEq(paymentToken.balanceOf(USER), 0);
        assertEq(usdplus.balanceOf(address(redeemer)), 0);
    }

    function test_rescueFunds(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max / 2);

        uint256 balanceBefore = usdplus.balanceOf(USER);

        vm.prank(ADMIN);
        redeemer.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        vm.prank(USER);
        usdplus.transfer(address(redeemer), amount);

        assertEq(usdplus.balanceOf(USER), balanceBefore - amount);

        // not admin
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), redeemer.DEFAULT_ADMIN_ROLE()
            )
        );
        redeemer.rescueFunds(USER, amount);

        vm.prank(ADMIN);
        redeemer.rescueFunds(USER, amount);

        assertEq(usdplus.balanceOf(USER), balanceBefore);
    }
}
