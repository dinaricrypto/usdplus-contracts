// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {
    IAccessControlDefaultAdminRules,
    IAccessControl
} from "openzeppelin-contracts/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import {TransferRestrictor} from "../src/TransferRestrictor.sol";
import "../src/UsdPlusMinter.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {SigUtils} from "./utils/SigUtils.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {MockToken} from "./utils/mocks/MockToken.sol";

contract UsdPlusMinterTest is Test {
    event PaymentRecipientSet(address indexed paymentRecipient);
    event PaymentTokenOracleSet(IERC20 indexed paymentToken, AggregatorV3Interface oracle);
    event Issued(address indexed to, IERC20 indexed paymentToken, uint256 paymentTokenAmount, uint256 usdPlusAmount);

    TransferRestrictor transferRestrictor;
    UsdPlus usdplus;
    UsdPlusMinter minter;
    MockToken paymentToken;
    SigUtils sigUtils;

    uint256 public userPrivateKey;

    address public constant ADMIN = address(0x1234);
    address public constant TREASURY = address(0x1235);
    address public USER;
    address constant usdcPriceOracle = 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3;

    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function setUp() public {
        userPrivateKey = 0x1236;
        USER = vm.addr(userPrivateKey);
        transferRestrictor = new TransferRestrictor(ADMIN);
        UsdPlus usdplusImpl = new UsdPlus();
        usdplus = UsdPlus(
            address(
                new ERC1967Proxy(
                    address(usdplusImpl), abi.encodeCall(UsdPlus.initialize, (TREASURY, transferRestrictor, ADMIN))
                )
            )
        );
        UsdPlusMinter minterImpl = new UsdPlusMinter();
        minter = UsdPlusMinter(
            address(
                new ERC1967Proxy(
                    address(minterImpl), abi.encodeCall(UsdPlusMinter.initialize, (address(usdplus), TREASURY, ADMIN))
                )
            )
        );
        paymentToken = new MockToken("Money", "$");
        sigUtils = new SigUtils(paymentToken.DOMAIN_SEPARATOR());

        paymentToken.mint(USER, type(uint256).max);

        vm.prank(ADMIN);
        usdplus.setIssuerLimits(address(minter), type(uint256).max, 0);
    }

    function test_initialization() public {
        assertEq(minter.usdplus(), address(usdplus));
    }

    function test_setPaymentRecipient(address recipient) public {
        if (recipient == address(0)) {
            vm.expectRevert(UsdPlusMinter.ZeroAddress.selector);
            vm.prank(ADMIN);
            minter.setPaymentRecipient(recipient);
            return;
        }

        // non-admin cannot set payment recipient
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), minter.DEFAULT_ADMIN_ROLE()
            )
        );
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
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), minter.DEFAULT_ADMIN_ROLE()
            )
        );
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

    function test_mint_permit(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max / 2);

        SigUtils.Permit memory sigPermit = SigUtils.Permit({
            owner: USER,
            spender: address(minter),
            value: amount,
            nonce: 0,
            deadline: block.timestamp + 30 days
        });
        bytes32 digest = sigUtils.getTypedDataHash(sigPermit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

        bytes memory signature = abi.encodePacked(r, s, v);

        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle));

        assertEq(usdplus.balanceOf(USER), 0);
        uint256 balanceBefore = paymentToken.balanceOf(USER);

        Permit memory permit = Permit({
            owner: sigPermit.owner,
            spender: sigPermit.spender,
            value: sigPermit.value,
            nonce: sigPermit.nonce,
            deadline: sigPermit.deadline
        });

        assertEq(minter.hasRole(minter.DEFAULT_ADMIN_ROLE(), ADMIN), true);

        vm.startPrank(ADMIN);
        minter.grantRole(minter.PRIVATE_MINTER_ROLE(), address(this));
        vm.stopPrank();

        bytes memory wrongSignature = abi.encodePacked(r, v, s);
        // should revert for ECDSAInvalidSignature next ECDSAInvalidSignatureS(bytesS)
        vm.expectRevert();
        minter.privateMint(paymentToken, permit, wrongSignature);

        vm.startPrank(ADMIN);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, ADMIN, minter.PRIVATE_MINTER_ROLE()
            )
        );
        minter.privateMint(paymentToken, permit, signature);
        vm.stopPrank();

        vm.startPrank(ADMIN);
        minter.grantRole(minter.PRIVATE_MINTER_ROLE(), ADMIN);

        uint256 issued = minter.privateMint(paymentToken, permit, signature);
        vm.stopPrank();

        assertEq(issued, amount);
        assertEq(usdplus.balanceOf(USER), issued);
        assertEq(paymentToken.balanceOf(USER), balanceBefore - issued);
    }
}
