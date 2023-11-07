// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {TransferRestrictor} from "../src/TransferRestrictor.sol";
import "../src/Minter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract MinterTest is Test {
    event PaymentRecipientSet(address indexed paymentRecipient);
    event PaymentTokenOracleSet(IERC20 indexed paymentToken, AggregatorV3Interface oracle);
    event Issued(address indexed to, IERC20 indexed paymentToken, uint256 paymentAmount, uint256 issueAmount);

    TransferRestrictor transferRestrictor;
    UsdPlus usdplus;
    Minter minter;
    ERC20Mock paymentToken;

    address public constant ADMIN = address(0x1234);
    address public constant TREASURY = address(0x1235);
    address public constant USER = address(0x1238);
    address constant usdcPriceOracle = 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3;

    function setUp() public {
        transferRestrictor = new TransferRestrictor(ADMIN);
        usdplus = new UsdPlus(TREASURY, transferRestrictor, ADMIN);
        minter = new Minter(usdplus, TREASURY, ADMIN);
        paymentToken = new ERC20Mock();

        paymentToken.mint(USER, type(uint256).max);
    }

    function test_setPaymentRecipient(address recipient) public {
        // non-admin cannot set payment recipient
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        minter.setPaymentRecipient(recipient);

        // admin can set payment recipient
        vm.expectEmit(true, true, true, true);
        emit PaymentRecipientSet(recipient);
        vm.prank(ADMIN);
        minter.setPaymentRecipient(recipient);
        assertEq(minter.paymentRecipient(), recipient);
    }

    function test_setPaymentTokenOracle(IERC20 token, address oracle) public {
        // non-admin cannot set payment token oracle
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        minter.setPaymentTokenOracle(token, AggregatorV3Interface(oracle));

        // admin can set payment token oracle
        vm.expectEmit(true, true, true, true);
        emit PaymentTokenOracleSet(token, AggregatorV3Interface(oracle));
        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(token, AggregatorV3Interface(oracle));
        assertEq(address(minter.paymentTokenOracle(token)), oracle);
    }

    function test_issueAmount(uint256 amount) public {
        vm.assume(amount < type(uint256).max / 2);

        // payment token oracle not set
        vm.expectRevert(abi.encodeWithSelector(Minter.PaymentNotAccepted.selector));
        minter.issueAmount(paymentToken, amount);

        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        minter.issueAmount(paymentToken, amount);
    }

    function test_issueToZeroAddressReverts(uint256 amount) public {
        vm.expectRevert(abi.encodeWithSelector(Minter.ZeroAddress.selector));
        minter.issue(address(0), paymentToken, amount);
    }

    function test_issueZeroAmountReverts() public {
        vm.expectRevert(abi.encodeWithSelector(Minter.ZeroAmount.selector));
        minter.issue(USER, paymentToken, 0);
    }

    function test_issue(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max / 2);

        vm.startPrank(ADMIN);
        usdplus.grantRole(usdplus.MINTER_ROLE(), address(minter));
        vm.stopPrank();

        // payment token oracle not set
        vm.expectRevert(abi.encodeWithSelector(Minter.PaymentNotAccepted.selector));
        minter.issue(USER, paymentToken, amount);

        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        vm.prank(USER);
        paymentToken.approve(address(minter), amount);

        uint256 issueEstimate = minter.issueAmount(paymentToken, amount);

        vm.expectEmit(true, true, true, true);
        emit Issued(USER, paymentToken, amount, issueEstimate);
        vm.prank(USER);
        uint256 issued = minter.issue(USER, paymentToken, amount);
        assertEq(issued, issueEstimate);
    }
}
