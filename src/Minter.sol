// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {UsdPlus} from "./UsdPlus.sol";
import {UsdPlusPlus} from "./UsdPlusPlus.sol";

/// @notice USD+ minter
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/Minter.sol)
contract Minter is Ownable {
    using SafeERC20 for IERC20;

    event PaymentRecipientSet(address indexed paymentRecipient);
    event PaymentTokenOracleSet(IERC20 indexed paymentToken, AggregatorV3Interface oracle);
    event Issued(address indexed receiver, IERC20 indexed paymentToken, uint256 paymentAmount, uint256 issueAmount);

    error ZeroAddress();
    error ZeroAmount();
    error PaymentNotAccepted();

    /// @notice USD+
    UsdPlus public immutable usdplus;

    /// @notice stUSD+
    UsdPlusPlus public immutable usdplusplus;

    /// @notice receiver of payment tokens
    address public paymentRecipient;

    /// @notice is this payment token accepted?
    mapping(IERC20 paymentToken => AggregatorV3Interface oracle) public paymentTokenOracle;

    constructor(UsdPlusPlus _usdplusplus, address _paymentRecipient, address initialOwner) Ownable(initialOwner) {
        if (_paymentRecipient == address(0)) revert ZeroAddress();

        usdplusplus = _usdplusplus;
        usdplus = UsdPlus(_usdplusplus.asset());
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

    /// @notice calculate USD+ amount to mint for payment
    /// @param paymentToken payment token
    /// @param paymentTokenAmount amount of payment token
    function previewIssueAmount(IERC20 paymentToken, uint256 paymentTokenAmount) public view returns (uint256) {
        AggregatorV3Interface oracle = paymentTokenOracle[paymentToken];
        if (address(oracle) == address(0)) revert PaymentNotAccepted();

        uint8 oracleDecimals = oracle.decimals();
        // slither-disable-next-line unused-return
        (, int256 price,,,) = oracle.latestRoundData();

        return Math.mulDiv(paymentTokenAmount, uint256(price), 10 ** uint256(oracleDecimals));
    }

    /// @notice mint USD+ for payment
    /// @param receiver recipient
    /// @param owner owner of payment token
    /// @param paymentToken payment token
    /// @param paymentTokenAmount amount of payment token to spend
    /// @return amount of USD+ minted
    function issue(address receiver, address owner, IERC20 paymentToken, uint256 paymentTokenAmount)
        public
        returns (uint256)
    {
        if (receiver == address(0)) revert ZeroAddress();
        if (paymentTokenAmount == 0) revert ZeroAmount();

        uint256 _issueAmount = previewIssueAmount(paymentToken, paymentTokenAmount);
        emit Issued(receiver, paymentToken, paymentTokenAmount, _issueAmount);

        paymentToken.safeTransferFrom(owner, paymentRecipient, paymentTokenAmount);
        usdplus.mint(receiver, _issueAmount);

        return _issueAmount;
    }

    /// @notice mint USD+ for payment and deposit in USD++
    /// @param receiver recipient
    /// @param owner owner of payment token
    /// @param paymentToken payment token
    /// @param paymentTokenAmount amount of payment token to spend
    /// @return amount of USD++ minted
    function issueAndDeposit(address receiver, address owner, IERC20 paymentToken, uint256 paymentTokenAmount)
        external
        returns (uint256)
    {
        uint256 _issueAmount = issue(address(this), owner, paymentToken, paymentTokenAmount);
        usdplus.approve(address(usdplusplus), _issueAmount);
        return usdplusplus.deposit(_issueAmount, receiver);
    }
}
