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
import {UnityOracle} from "../src/mocks/UnityOracle.sol";

contract UsdPlusMinterTest is Test {
    event PaymentRecipientSet(address indexed paymentRecipient);
    event PaymentTokenOracleSet(IERC20 indexed paymentToken, AggregatorV3Interface oracle, uint256 heartbeat);
    event Issued(address indexed to, IERC20 indexed paymentToken, uint256 paymentTokenAmount, uint256 usdPlusAmount);

    TransferRestrictor transferRestrictor;
    UsdPlus usdplus;
    UsdPlusMinter minter;
    MockToken paymentToken;
    SigUtils sigUtils;

    uint256 public userPrivateKey;

    address public constant ADMIN = address(0x1234);
    address public constant TREASURY = address(0x1235);
    address public constant UPGRADER = address(0x1236);
    address public USER;
    address constant usdcPriceOracle = 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3;

    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function setUp() public {
        userPrivateKey = 0x1236;
        USER = vm.addr(userPrivateKey);
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
        UsdPlusMinter minterImpl = new UsdPlusMinter();
        minter = UsdPlusMinter(
            address(
                new ERC1967Proxy(
                    address(minterImpl),
                    abi.encodeCall(UsdPlusMinter.initialize, (address(usdplus), TREASURY, ADMIN, UPGRADER))
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

    function test_version() public {
        assertEq(minter.version(), 2);
        assertEq(minter.publicVersion(), "1.0.0");
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

    function test_setPaymentTokenOracle(IERC20 token, address oracle, uint256 heartbeat) public {
        // non-admin cannot set payment token oracle
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), minter.DEFAULT_ADMIN_ROLE()
            )
        );
        minter.setPaymentTokenOracle(token, AggregatorV3Interface(oracle), heartbeat);

        // admin can set payment token oracle
        vm.expectEmit(true, true, true, true);
        emit PaymentTokenOracleSet(token, AggregatorV3Interface(oracle), heartbeat);
        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(token, AggregatorV3Interface(oracle), heartbeat);
        IUsdPlusMinter.PaymentTokenOracleInfo memory info = minter.paymentTokenOracle(token);
        assertEq(address(info.oracle), oracle);
        assertEq(info.heartbeat, heartbeat);
    }

    function test_pause_unpause() public {
        // non-admin cannot pause
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), minter.DEFAULT_ADMIN_ROLE()
            )
        );
        minter.pause();

        // admin can pause
        vm.prank(ADMIN);
        minter.pause();
        assertEq(minter.paused(), true);

        // non-admin cannot unpause
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), minter.DEFAULT_ADMIN_ROLE()
            )
        );
        minter.unpause();

        vm.prank(ADMIN);
        minter.unpause();
        assertEq(minter.paused(), false);
    }

    function test_deposit() public {
        UnityOracle unityOracle = new UnityOracle();

        // Test USDC (6 decimals)
        MockToken usdc = new MockToken("USDC", "USDC");
        usdc.mint(USER, 1000_000000);
        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(IERC20(address(usdc)), unityOracle, 0);

        // USDC test cases
        uint256 previewAmount = minter.previewDeposit(IERC20(address(usdc)), 1_000000);
        assertEq(previewAmount, 1_000000, "1 USDC should preview to 1 USD+");

        previewAmount = minter.previewDeposit(IERC20(address(usdc)), 1000_000000);
        assertEq(previewAmount, 1000_000000, "1000 USDC should preview to 1000 USD+");

        vm.startPrank(USER);
        usdc.approve(address(minter), 1000_000000);
        uint256 mintedAmount = minter.deposit(IERC20(address(usdc)), 1000_000000, USER, previewAmount);
        vm.stopPrank();
        assertEq(mintedAmount, 1000_000000, "Should mint 1000 USD+");

        // Test ETH (18 decimals)
        MockToken eth = new MockToken("ETH", "ETH");
        eth.setDecimals(18);
        eth.mint(USER, 1000 * 1e18);
        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(IERC20(address(eth)), unityOracle, 0);

        // ETH test cases
        previewAmount = minter.previewDeposit(IERC20(address(eth)), 1 ether);
        assertEq(previewAmount, 1_000000, "1 ETH should preview to 1 USD+");

        previewAmount = minter.previewDeposit(IERC20(address(eth)), 0.5 ether);
        assertEq(previewAmount, 500000, "0.5 ETH should preview to 0.5 USD+");

        previewAmount = minter.previewDeposit(IERC20(address(eth)), 1000 ether);
        assertEq(previewAmount, 1000_000000, "1000 ETH should preview to 1000 USD+");

        vm.startPrank(USER);
        eth.approve(address(minter), 1000 ether);
        mintedAmount = minter.deposit(IERC20(address(eth)), 1000 ether, USER, previewAmount);
        vm.stopPrank();
        assertEq(mintedAmount, 1000_000000, "Should mint 1000 USD+");
    }

    function test_previewMint() public {
        UnityOracle unityOracle = new UnityOracle();

        // Test USDC (6 decimals)
        MockToken usdc = new MockToken("USDC", "USDC");
        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(IERC20(address(usdc)), unityOracle, 0);

        // USDC test cases
        uint256 paymentAmount = minter.previewMint(IERC20(address(usdc)), 1_000000);
        assertEq(paymentAmount, 1_000000, "Should need 1 USDC for 1 USD+");

        paymentAmount = minter.previewMint(IERC20(address(usdc)), 1000_000000);
        assertEq(paymentAmount, 1000_000000, "Should need 1000 USDC for 1000 USD+");

        // Test ETH (18 decimals)
        MockToken eth = new MockToken("ETH", "ETH");
        eth.setDecimals(18);
        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(IERC20(address(eth)), unityOracle, 0);

        // ETH test cases
        paymentAmount = minter.previewMint(IERC20(address(eth)), 1_000000);
        assertEq(paymentAmount, 1 ether, "Should need 1 ETH for 1 USD+");

        paymentAmount = minter.previewMint(IERC20(address(eth)), 500000);
        assertEq(paymentAmount, 0.5 ether, "Should need 0.5 ETH for 0.5 USD+");

        paymentAmount = minter.previewMint(IERC20(address(eth)), 1000_000000);
        assertEq(paymentAmount, 1000 ether, "Should need 1000 ETH for 1000 USD+");
    }

    function test_previewDeposit(uint256 amount) public {
        vm.assume(amount < type(uint256).max / 2);

        // usdplus
        assertEq(minter.previewDeposit(IERC20(address(usdplus)), amount), amount);

        // payment token oracle not set
        vm.expectRevert(IUsdPlusMinter.PaymentTokenNotAccepted.selector);
        minter.previewDeposit(paymentToken, amount);

        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle), 0);

        minter.previewDeposit(paymentToken, amount);
    }

    function test_depositToZeroAddressReverts(uint256 amount) public {
        vm.expectRevert(UsdPlusMinter.ZeroAddress.selector);
        minter.deposit(paymentToken, amount, address(0), 0);
    }

    function test_depositZeroAmountReverts() public {
        vm.expectRevert(UsdPlusMinter.ZeroAmount.selector);
        minter.deposit(paymentToken, 0, USER, 0);
    }

    function test_depositUnsetOracleReverts(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max / 2);

        vm.expectRevert(IUsdPlusMinter.PaymentTokenNotAccepted.selector);
        minter.deposit(paymentToken, amount, USER, 0);
    }

    function test_depositSlippageReverts(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max / 2);

        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle), 0);

        uint256 issueEstimate = minter.previewDeposit(paymentToken, amount);
        vm.assume(issueEstimate > 0);

        vm.prank(USER);
        paymentToken.approve(address(minter), amount);

        vm.expectRevert(UsdPlusMinter.SlippageViolation.selector);
        minter.deposit(paymentToken, amount, USER, issueEstimate + 1);
    }

    function test_deposit(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max / 2);

        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle), 0);

        uint256 issueEstimate = minter.previewDeposit(paymentToken, amount);
        vm.assume(issueEstimate > 0);

        vm.prank(USER);
        paymentToken.approve(address(minter), amount);

        vm.expectEmit(true, true, true, true);
        emit Issued(USER, paymentToken, amount, issueEstimate);
        vm.prank(USER);
        uint256 issued = minter.deposit(paymentToken, amount, USER, issueEstimate);
        assertEq(issued, issueEstimate);

        // deposit usdplus returns usdplus
        vm.prank(USER);
        usdplus.approve(address(minter), issued);

        vm.expectEmit(true, true, true, true);
        emit Issued(USER, IERC20(address(usdplus)), issued, issued);
        vm.prank(USER);
        uint256 issuedplus = minter.deposit(IERC20(address(usdplus)), issued, USER, issueEstimate);
        assertEq(issuedplus, issued);
        assertEq(usdplus.balanceOf(USER), issuedplus);
    }

    function test_mintZeroAddressReverts(uint256 amount) public {
        vm.expectRevert(UsdPlusMinter.ZeroAddress.selector);
        minter.mint(paymentToken, amount, address(0), 0);
    }

    function test_mintZeroAmountReverts() public {
        vm.expectRevert(UsdPlusMinter.ZeroAmount.selector);
        minter.mint(paymentToken, 0, USER, 0);
    }

    function test_mintUnsetOracleReverts(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max / 2);

        vm.expectRevert(IUsdPlusMinter.PaymentTokenNotAccepted.selector);
        minter.mint(paymentToken, amount, USER, 0);
    }

    function test_mintSlippageReverts(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max / 2);

        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle), 0);

        uint256 paymentEstimate = minter.previewMint(paymentToken, amount);
        vm.assume(paymentEstimate > 0);

        vm.prank(USER);
        paymentToken.approve(address(minter), paymentEstimate);

        vm.expectRevert(UsdPlusMinter.SlippageViolation.selector);
        minter.mint(paymentToken, amount, USER, paymentEstimate - 1);
    }

    function test_mint(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max / 2);

        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle), 0);

        uint256 paymentEstimate = minter.previewMint(paymentToken, amount);
        vm.assume(paymentEstimate > 0);

        vm.prank(USER);
        paymentToken.approve(address(minter), paymentEstimate);

        vm.expectEmit(true, true, true, true);
        emit Issued(USER, paymentToken, paymentEstimate, amount);
        vm.prank(USER);
        uint256 issued = minter.mint(paymentToken, amount, USER, paymentEstimate);
        assertEq(issued, paymentEstimate);
    }

    function test_privateMint(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max / 2);

        vm.prank(ADMIN);
        minter.setPaymentTokenOracle(paymentToken, AggregatorV3Interface(usdcPriceOracle), 0);

        uint256 issueEstimate = minter.previewDeposit(paymentToken, amount);
        vm.assume(issueEstimate > 0);

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

        assertEq(usdplus.balanceOf(USER), 0);
        uint256 balanceBefore = paymentToken.balanceOf(USER);

        Permit memory permit = Permit({
            owner: sigPermit.owner,
            spender: sigPermit.spender,
            value: sigPermit.value,
            nonce: sigPermit.nonce,
            deadline: sigPermit.deadline
        });

        vm.startPrank(ADMIN);
        minter.grantRole(minter.PRIVATE_MINTER_ROLE(), address(this));
        vm.stopPrank();

        bytes memory wrongSignature = abi.encodePacked(r, v, s);
        vm.expectRevert(SelfPermit.PermitFailure.selector);
        minter.privateMint(paymentToken, permit, wrongSignature);

        vm.startPrank(ADMIN);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, ADMIN, minter.PRIVATE_MINTER_ROLE()
            )
        );
        minter.privateMint(paymentToken, permit, signature);
        vm.stopPrank();

        uint256 issued = minter.privateMint(paymentToken, permit, signature);
        vm.stopPrank();

        assertEq(issued, issueEstimate);
        assertEq(usdplus.balanceOf(USER), issued);
        assertEq(paymentToken.balanceOf(USER), balanceBefore - amount);
    }
}
