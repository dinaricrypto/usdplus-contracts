// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {IUsdPlusMinter} from "./IUsdPlusMinter.sol";
import {UsdPlus} from "./UsdPlus.sol";
import {StakedUsdPlus} from "./StakedUsdPlus.sol";

/// @notice USD+ minter
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/Minter.sol)
contract UsdPlusMinter is IUsdPlusMinter, Ownable {
    using SafeERC20 for IERC20;
    using SafeERC20 for UsdPlus;

    error ZeroAddress();
    error ZeroAmount();

    UsdPlus public immutable usdplus;

    StakedUsdPlus public immutable stakedUsdplus;

    address public paymentRecipient;

    mapping(IERC20 => AggregatorV3Interface) public paymentTokenOracle;

    constructor(StakedUsdPlus _stakedUsdplus, address _paymentRecipient, address initialOwner) Ownable(initialOwner) {
        if (_paymentRecipient == address(0)) revert ZeroAddress();

        stakedUsdplus = _stakedUsdplus;
        usdplus = UsdPlus(_stakedUsdplus.asset());
        paymentRecipient = _paymentRecipient;
    }

    // ------------------ Admin ------------------

    /// @notice set payment recipient
    function setPaymentRecipient(address newPaymentRecipient) external onlyOwner {
        if (newPaymentRecipient == address(0)) revert ZeroAddress();

        paymentRecipient = newPaymentRecipient;
        emit PaymentRecipientSet(newPaymentRecipient);
    }

    /// @notice set payment token oracle
    /// @param paymentToken payment token
    /// @param oracle oracle
    function setPaymentTokenOracle(IERC20 paymentToken, AggregatorV3Interface oracle) external onlyOwner {
        paymentTokenOracle[paymentToken] = oracle;
        emit PaymentTokenOracleSet(paymentToken, oracle);
    }

    // ------------------ Mint ------------------

    /// @inheritdoc IUsdPlusMinter
    function getOraclePrice(IERC20 paymentToken) public view returns (uint256, uint8) {
        AggregatorV3Interface oracle = paymentTokenOracle[paymentToken];
        if (address(oracle) == address(0)) revert PaymentTokenNotAccepted();

        // slither-disable-next-line unused-return
        (, int256 price,,,) = oracle.latestRoundData();
        uint8 oracleDecimals = oracle.decimals();

        return (uint256(price), oracleDecimals);
    }

    /// @inheritdoc IUsdPlusMinter
    function previewDeposit(IERC20 paymentToken, uint256 paymentTokenAmount) public view returns (uint256) {
        (uint256 price, uint8 oracleDecimals) = getOraclePrice(paymentToken);
        return Math.mulDiv(paymentTokenAmount, price, 10 ** uint256(oracleDecimals), Math.Rounding.Floor);
    }

    /// @inheritdoc IUsdPlusMinter
    function deposit(IERC20 paymentToken, uint256 paymentTokenAmount, address receiver)
        public
        returns (uint256 usdPlusAmount)
    {
        if (receiver == address(0)) revert ZeroAddress();
        if (paymentTokenAmount == 0) revert ZeroAmount();

        usdPlusAmount = previewDeposit(paymentToken, paymentTokenAmount);
        if (usdPlusAmount == 0) revert ZeroAmount();

        _issue(paymentToken, paymentTokenAmount, usdPlusAmount, receiver);
    }

    function _issue(IERC20 paymentToken, uint256 paymentTokenAmount, uint256 usdPlusAmount, address receiver)
        internal
    {
        emit Issued(receiver, paymentToken, paymentTokenAmount, usdPlusAmount);

        paymentToken.safeTransferFrom(msg.sender, paymentRecipient, paymentTokenAmount);
        usdplus.mint(receiver, usdPlusAmount);
    }

    /// @inheritdoc IUsdPlusMinter
    function previewDepositAndStake(IERC20 paymentToken, uint256 paymentTokenAmount) external view returns (uint256) {
        return stakedUsdplus.previewDeposit(previewDeposit(paymentToken, paymentTokenAmount));
    }

    /// @inheritdoc IUsdPlusMinter
    function depositAndStake(IERC20 paymentToken, uint256 paymentTokenAmount, address receiver)
        external
        returns (uint256)
    {
        uint256 _issueAmount = deposit(paymentToken, paymentTokenAmount, address(this));
        StakedUsdPlus _stakedUsdplus = stakedUsdplus;
        usdplus.safeIncreaseAllowance(address(_stakedUsdplus), _issueAmount);
        return _stakedUsdplus.deposit(_issueAmount, receiver);
    }

    /// @inheritdoc IUsdPlusMinter
    function previewMint(IERC20 paymentToken, uint256 usdPlusAmount) public view returns (uint256) {
        (uint256 price, uint8 oracleDecimals) = getOraclePrice(paymentToken);
        return Math.mulDiv(usdPlusAmount, 10 ** uint256(oracleDecimals), price, Math.Rounding.Ceil);
    }

    /// @inheritdoc IUsdPlusMinter
    function mint(IERC20 paymentToken, uint256 usdPlusAmount, address receiver)
        public
        returns (uint256 paymentTokenAmount)
    {
        if (receiver == address(0)) revert ZeroAddress();
        if (usdPlusAmount == 0) revert ZeroAmount();

        paymentTokenAmount = previewMint(paymentToken, usdPlusAmount);
        if (paymentTokenAmount == 0) revert ZeroAmount();

        _issue(paymentToken, paymentTokenAmount, usdPlusAmount, receiver);
    }

    /// @inheritdoc IUsdPlusMinter
    function mintAndStake(IERC20 paymentToken, uint256 usdPlusAmount, address receiver) external returns (uint256) {
        mint(paymentToken, usdPlusAmount, address(this));
        StakedUsdPlus _stakedUsdplus = stakedUsdplus;
        usdplus.safeIncreaseAllowance(address(_stakedUsdplus), usdPlusAmount);
        return _stakedUsdplus.deposit(usdPlusAmount, receiver);
    }
}
