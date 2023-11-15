// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {StakedUsdPlus} from "../src/StakedUsdPlus.sol";
import {TransferRestrictor} from "../src/TransferRestrictor.sol";
import "../src/UsdPlusRedeemer.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract UsdPlusRedeemerTest is Test {
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
    StakedUsdPlus stakedUsdplus;
    UsdPlusRedeemer redeemer;
    ERC20Mock paymentToken;

    address public constant ADMIN = address(0x1234);
    address public constant FULFILLER = address(0x1235);
    address public constant USER = address(0x1238);
    address constant usdcPriceOracle = 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3;

    function setUp() public {
        transferRestrictor = new TransferRestrictor(ADMIN);
        UsdPlus usdplusImpl = new UsdPlus();
        usdplus = UsdPlus(
            address(
                new ERC1967Proxy(address(usdplusImpl), abi.encodeCall(UsdPlus.initialize, (address(this), transferRestrictor, ADMIN)))
            )
        );
        StakedUsdPlus stakedusdplusImpl = new StakedUsdPlus();
        stakedUsdplus = StakedUsdPlus(
            address(
                new ERC1967Proxy(address(stakedusdplusImpl), abi.encodeCall(StakedUsdPlus.initialize, (usdplus, ADMIN)))
            )
        );
        UsdPlusRedeemer redeemerImpl = new UsdPlusRedeemer();
        redeemer = UsdPlusRedeemer(
            address(
                new ERC1967Proxy(address(redeemerImpl), abi.encodeCall(UsdPlusRedeemer.initialize, (stakedUsdplus, ADMIN)))
            )
        );
        paymentToken = new ERC20Mock();

        vm.startPrank(ADMIN);
        usdplus.grantRole(usdplus.MINTER_ROLE(), address(this));
        redeemer.grantRole(redeemer.FULFILLER_ROLE(), FULFILLER);
        vm.stopPrank();

        usdplus.mint(USER, type(uint256).max);
        paymentToken.mint(FULFILLER, type(uint256).max);
    }

    function test_initialization() public {
        assertEq(address(redeemer.stakedUsdplus()), address(stakedUsdplus));
        assertEq(address(redeemer.usdplus()), address(usdplus));
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

    function test_redemptionAmount(uint256 amount) public {
        vm.assume(amount < type(uint256).max / 2);

        // payment token oracle not set
        vm.expectRevert(abi.encodeWithSelector(UsdPlusRedeemer.PaymentTokenNotAccepted.selector));
        redeemer.previewRedeem(paymentToken, amount);

        vm.prank(ADMIN);
        redeemer.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        redeemer.previewRedeem(paymentToken, amount);
    }

    function test_requestToZeroAddressReverts(uint256 amount) public {
        vm.expectRevert(abi.encodeWithSelector(UsdPlusRedeemer.ZeroAddress.selector));
        redeemer.request(address(0), USER, paymentToken, amount);
    }

    function test_requestZeroAmountReverts() public {
        vm.expectRevert(abi.encodeWithSelector(UsdPlusRedeemer.ZeroAmount.selector));
        redeemer.request(USER, USER, paymentToken, 0);
    }

    function test_request(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max / 2);

        vm.prank(ADMIN);
        redeemer.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        vm.prank(USER);
        usdplus.approve(address(redeemer), amount);

        uint256 redemptionEstimate = redeemer.previewRedeem(paymentToken, amount);

        // reverts if redemption amount is 0
        if (redemptionEstimate == 0) {
            vm.expectRevert(abi.encodeWithSelector(UsdPlusRedeemer.ZeroAmount.selector));
            redeemer.request(USER, USER, paymentToken, amount);
            return;
        }

        vm.expectEmit(true, true, true, true);
        emit RequestCreated(0, USER, paymentToken, redemptionEstimate, amount);
        vm.prank(USER);
        uint256 ticket = redeemer.request(USER, USER, paymentToken, amount);

        UsdPlusRedeemer.Request memory request = redeemer.requests(ticket);
        assertEq(request.paymentAmount, redemptionEstimate);
    }

    function test_unstakeAndRequest(uint104 amount) public {
        vm.assume(amount > 0);

        vm.startPrank(USER);
        usdplus.approve(address(stakedUsdplus), amount);
        uint256 stakedAmount = stakedUsdplus.deposit(amount, USER);
        vm.stopPrank();

        vm.prank(ADMIN);
        redeemer.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        uint256 redemptionEstimate = redeemer.previewUnstakeAndRedeem(paymentToken, stakedAmount);
        vm.assume(redemptionEstimate > 0);

        vm.prank(USER);
        stakedUsdplus.approve(address(redeemer), stakedAmount);

        vm.expectEmit(true, true, true, true);
        emit RequestCreated(0, USER, paymentToken, redemptionEstimate, amount);
        vm.prank(USER);
        uint256 ticket = redeemer.unstakeAndRequest(USER, USER, paymentToken, stakedAmount);

        UsdPlusRedeemer.Request memory request = redeemer.requests(ticket);
        assertEq(request.paymentAmount, redemptionEstimate);
    }

    function test_cancelInvalidTicketReverts(uint256 ticket) public {
        vm.expectRevert(abi.encodeWithSelector(UsdPlusRedeemer.InvalidTicket.selector));
        vm.prank(FULFILLER);
        redeemer.cancel(ticket);
    }

    function test_cancel(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max / 2);

        vm.prank(ADMIN);
        redeemer.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        uint256 redemptionEstimate = redeemer.previewRedeem(paymentToken, amount);
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
        vm.expectRevert(abi.encodeWithSelector(UsdPlusRedeemer.InvalidTicket.selector));
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