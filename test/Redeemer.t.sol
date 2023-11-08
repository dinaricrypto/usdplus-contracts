// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {UsdPlusPlus} from "../src/UsdPlusPlus.sol";
import {TransferRestrictor} from "../src/TransferRestrictor.sol";
import "../src/Redeemer.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract RedeemerTest is Test {
    event PaymentTokenOracleSet(IERC20 indexed paymentToken, AggregatorV3Interface oracle);
    event RequestCreated(
        uint256 indexed ticket, address indexed to, IERC20 paymentToken, uint256 paymentAmount, uint256 burnAmount
    );
    event RequestCancelled(uint256 indexed ticket, address indexed to);
    event RequestFulfilled(
        uint256 indexed ticket, address indexed to, IERC20 paymentToken, uint256 paymentAmount, uint256 burnAmount
    );

    TransferRestrictor transferRestrictor;
    UsdPlus usdplus;
    UsdPlusPlus usdplusplus;
    Redeemer redeemer;
    ERC20Mock paymentToken;

    address public constant ADMIN = address(0x1234);
    address public constant FULFILLER = address(0x1235);
    address public constant USER = address(0x1238);
    address constant usdcPriceOracle = 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3;

    function setUp() public {
        transferRestrictor = new TransferRestrictor(ADMIN);
        usdplus = new UsdPlus(address(this), transferRestrictor, ADMIN);
        usdplusplus = new UsdPlusPlus(usdplus, ADMIN);
        redeemer = new Redeemer(usdplusplus, ADMIN);
        paymentToken = new ERC20Mock();

        vm.startPrank(ADMIN);
        usdplus.grantRole(usdplus.MINTER_ROLE(), address(this));
        redeemer.grantRole(redeemer.FULFILLER_ROLE(), FULFILLER);
        vm.stopPrank();

        usdplus.mint(USER, type(uint256).max);
        paymentToken.mint(FULFILLER, type(uint256).max);
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

    function test_redemptionAmount(uint256 amount) public {
        vm.assume(amount < type(uint256).max / 2);

        // payment token oracle not set
        vm.expectRevert(abi.encodeWithSelector(Redeemer.PaymentNotAccepted.selector));
        redeemer.previewRedemptionAmount(paymentToken, amount);

        vm.prank(ADMIN);
        redeemer.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        redeemer.previewRedemptionAmount(paymentToken, amount);
    }

    function test_requestToZeroAddressReverts(uint256 amount) public {
        vm.expectRevert(abi.encodeWithSelector(Redeemer.ZeroAddress.selector));
        redeemer.request(address(0), USER, paymentToken, amount);
    }

    function test_requestZeroAmountReverts() public {
        vm.expectRevert(abi.encodeWithSelector(Redeemer.ZeroAmount.selector));
        redeemer.request(USER, USER, paymentToken, 0);
    }

    function test_request(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max / 2);

        vm.prank(ADMIN);
        redeemer.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        vm.prank(USER);
        usdplus.approve(address(redeemer), amount);

        uint256 redemptionEstimate = redeemer.previewRedemptionAmount(paymentToken, amount);

        // reverts if redemption amount is 0
        if (redemptionEstimate == 0) {
            vm.expectRevert(abi.encodeWithSelector(Redeemer.ZeroAmount.selector));
            redeemer.request(USER, USER, paymentToken, amount);
            return;
        }

        vm.expectEmit(true, true, true, true);
        emit RequestCreated(0, USER, paymentToken, redemptionEstimate, amount);
        vm.prank(USER);
        uint256 ticket = redeemer.request(USER, USER, paymentToken, amount);

        (,,, uint256 paymentAmount,) = redeemer.requests(ticket);
        assertEq(paymentAmount, redemptionEstimate);
    }

    function test_cancelInvalidTicketReverts(uint256 ticket) public {
        vm.expectRevert(abi.encodeWithSelector(Redeemer.InvalidTicket.selector));
        vm.prank(FULFILLER);
        redeemer.cancel(ticket);
    }

    function test_cancel(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max / 2);

        vm.prank(ADMIN);
        redeemer.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        uint256 redemptionEstimate = redeemer.previewRedemptionAmount(paymentToken, amount);
        vm.assume(redemptionEstimate > 0);

        vm.startPrank(USER);
        usdplus.approve(address(redeemer), amount);
        uint256 ticket = redeemer.request(USER, USER, paymentToken, amount);
        vm.stopPrank();

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
    }

    function test_fulfillInvalidTicketReverts(uint256 ticket) public {
        vm.expectRevert(abi.encodeWithSelector(Redeemer.InvalidTicket.selector));
        vm.prank(FULFILLER);
        redeemer.fulfill(ticket);
    }

    function test_fulfill(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max / 2);

        vm.prank(ADMIN);
        redeemer.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        uint256 redemptionEstimate = redeemer.previewRedemptionAmount(paymentToken, amount);
        vm.assume(redemptionEstimate > 0);

        vm.startPrank(USER);
        usdplus.approve(address(redeemer), amount);
        uint256 ticket = redeemer.request(USER, USER, paymentToken, amount);
        vm.stopPrank();

        // not fulfiller
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), redeemer.FULFILLER_ROLE()
            )
        );
        redeemer.fulfill(ticket);

        // redeemer not burner
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(redeemer), usdplus.BURNER_ROLE()
            )
        );
        vm.prank(FULFILLER);
        redeemer.fulfill(ticket);

        vm.startPrank(ADMIN);
        usdplus.grantRole(usdplus.BURNER_ROLE(), address(redeemer));
        vm.stopPrank();

        vm.startPrank(FULFILLER);
        paymentToken.approve(address(redeemer), redemptionEstimate);

        vm.expectEmit(true, true, true, true);
        emit RequestFulfilled(ticket, USER, paymentToken, redemptionEstimate, amount);
        redeemer.fulfill(ticket);
        vm.stopPrank();
    }
}
