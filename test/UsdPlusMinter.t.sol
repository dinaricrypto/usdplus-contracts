// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {StakedUsdPlus} from "../src/StakedUsdPlus.sol";
import {TransferRestrictor} from "../src/TransferRestrictor.sol";
import "../src/UsdPlusMinter.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract UsdPlusMinterTest is Test {
    event PaymentRecipientSet(address indexed paymentRecipient);
    event PaymentTokenOracleSet(IERC20 indexed paymentToken, AggregatorV3Interface oracle);
    event Issued(address indexed to, IERC20 indexed paymentToken, uint256 paymentTokenAmount, uint256 usdPlusAmount);

    TransferRestrictor transferRestrictor;
    UsdPlus usdplus;
    StakedUsdPlus stakedUsdplus;
    UsdPlusMinter minter;
    ERC20Mock paymentToken;

    address public constant ADMIN = address(0x1234);
    address public constant TREASURY = address(0x1235);
    address public constant USER = address(0x1238);
    address constant usdcPriceOracle = 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3;

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
        UsdPlusMinter minterImpl = new UsdPlusMinter();
        minter = UsdPlusMinter(
            address(
                new ERC1967Proxy(
                    address(minterImpl), abi.encodeCall(UsdPlusMinter.initialize, (stakedUsdplus, TREASURY, ADMIN))
                )
            )
        );
        paymentToken = new ERC20Mock();

        paymentToken.mint(USER, type(uint256).max);

        vm.prank(ADMIN);
        usdplus.setIssuerLimits(address(minter), type(uint256).max, 0);
    }

    function test_initialization() public {
        assertEq(address(minter.stakedUsdplus()), address(stakedUsdplus));
        assertEq(address(minter.usdplus()), address(usdplus));
    }

    function test_setPaymentRecipient(address recipient) public {
        if (recipient == address(0)) {
            vm.expectRevert(UsdPlusMinter.ZeroAddress.selector);
            vm.prank(ADMIN);
            minter.setPaymentRecipient(recipient);
            return;
        }

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

    function test_previewDeposit(uint256 amount) public {
        vm.assume(amount < type(uint256).max / 2);

        // payment token oracle not set
        vm.expectRevert(IUsdPlusMinter.PaymentTokenNotAccepted.selector);
        minter.previewDeposit(paymentToken, amount);

        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        minter.previewDeposit(paymentToken, amount);
    }

    function test_depositToZeroAddressReverts(uint256 amount) public {
        vm.expectRevert(UsdPlusMinter.ZeroAddress.selector);
        minter.deposit(paymentToken, amount, address(0));
    }

    function test_depositZeroAmountReverts() public {
        vm.expectRevert(UsdPlusMinter.ZeroAmount.selector);
        minter.deposit(paymentToken, 0, USER);
    }

    function test_deposit(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max / 2);

        // payment token oracle not set
        vm.expectRevert(IUsdPlusMinter.PaymentTokenNotAccepted.selector);
        minter.deposit(paymentToken, amount, USER);

        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        uint256 issueEstimate = minter.previewDeposit(paymentToken, amount);
        vm.assume(issueEstimate > 0);

        vm.prank(USER);
        paymentToken.approve(address(minter), amount);

        vm.expectEmit(true, true, true, true);
        emit Issued(USER, paymentToken, amount, issueEstimate);
        vm.prank(USER);
        uint256 issued = minter.deposit(paymentToken, amount, USER);
        assertEq(issued, issueEstimate);
    }

    function test_depositAndStake(uint104 amount) public {
        vm.assume(amount > 0);

        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        uint256 issueEstimate = minter.previewDepositAndStake(paymentToken, amount);
        vm.assume(issueEstimate < type(uint104).max);

        vm.assume(minter.previewDeposit(paymentToken, amount) > 0);

        vm.prank(USER);
        paymentToken.approve(address(minter), amount);

        vm.prank(USER);
        uint256 issued = minter.depositAndStake(paymentToken, amount, USER);
        assertEq(issued, issueEstimate);
    }

    function test_mintZeroAddressReverts(uint256 amount) public {
        vm.expectRevert(UsdPlusMinter.ZeroAddress.selector);
        minter.mint(paymentToken, amount, address(0));
    }

    function test_mintZeroAmountReverts() public {
        vm.expectRevert(UsdPlusMinter.ZeroAmount.selector);
        minter.mint(paymentToken, 0, USER);
    }

    function test_mint(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max / 2);

        // payment token oracle not set
        vm.expectRevert(IUsdPlusMinter.PaymentTokenNotAccepted.selector);
        minter.mint(paymentToken, amount, USER);

        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        uint256 paymentEstimate = minter.previewMint(paymentToken, amount);
        vm.assume(paymentEstimate > 0);

        vm.prank(USER);
        paymentToken.approve(address(minter), paymentEstimate);

        vm.expectEmit(true, true, true, true);
        emit Issued(USER, paymentToken, paymentEstimate, amount);
        vm.prank(USER);
        uint256 issued = minter.mint(paymentToken, amount, USER);
        assertEq(issued, paymentEstimate);
    }

    function test_mintAndStake(uint104 amount) public {
        vm.assume(amount > 0);

        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        uint256 paymentEstimate = minter.previewMint(paymentToken, amount);
        vm.assume(paymentEstimate > 0);

        vm.prank(USER);
        paymentToken.approve(address(minter), paymentEstimate);

        uint256 issueEstimate = stakedUsdplus.previewDeposit(amount);

        vm.prank(USER);
        uint256 issued = minter.mintAndStake(paymentToken, amount, USER);
        assertEq(issued, issueEstimate);
    }
}
