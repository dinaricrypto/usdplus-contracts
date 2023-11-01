// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import "../src/Minter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MinterTest is Test {
    event PaymentRecipientSet(address indexed paymentRecipient);
    event PaymentTokenOracleSet(IERC20 indexed paymentToken, AggregatorV3Interface oracle);
    event Issued(address indexed to, IERC20 indexed paymentToken, uint256 paymentAmount, uint256 issueAmount);

    UsdPlus usdplus;
    Minter minter;

    address public constant ADMIN = address(0x1234);
    address public constant TREASURY = address(0x1235);
    address public constant USER = address(0x1238);
    address constant usdcPriceOracle = 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3;

    function setUp() public {
        usdplus = new UsdPlus(ADMIN);
        minter = new Minter(usdplus, TREASURY, ADMIN);
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

    function test_setPaymentTokenOracle(address oracle) public {
        // non-admin cannot set payment token oracle
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        minter.setPaymentTokenOracle(usdplus, AggregatorV3Interface(oracle));

        // admin can set payment token oracle
        vm.expectEmit(true, true, true, true);
        emit PaymentTokenOracleSet(usdplus, AggregatorV3Interface(oracle));
        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(usdplus, AggregatorV3Interface(oracle));
        assertEq(address(minter.paymentTokenOracle(usdplus)), oracle);
    }

    function test_issueAmount(uint256 amount) public {
        vm.assume(amount < type(uint256).max / 2);

        // payment token oracle not set
        vm.expectRevert(abi.encodeWithSelector(Minter.PaymentNotAccepted.selector));
        minter.issueAmount(usdplus, amount);

        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(usdplus, AggregatorV3Interface(usdcPriceOracle));

        minter.issueAmount(usdplus, amount);
    }

    // function test_issue() public {
    //     vm.prank(ADMIN);
    //     usdplus.grantRole(usdplus.MINTER_ROLE(), address(minter));

    // }
}
