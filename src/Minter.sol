// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {UsdPlus} from "./UsdPlus.sol";

/// @notice USD+ minter
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/Minter.sol)
contract Minter is Ownable {
    using SafeERC20 for IERC20;

    event PaymentRecipientSet(address indexed paymentRecipient);
    event PaymentTokenOracleSet(IERC20 indexed paymentToken, AggregatorV3Interface oracle);
    event Issued(address indexed to, IERC20 indexed paymentToken, uint256 paymentAmount, uint256 issueAmount);

    error ZeroAddress();
    error ZeroAmount();
    error PaymentTokenNotAccepted();

    /// @notice USD+
    UsdPlus public immutable usdplus;

    /// @notice receiver of payment tokens
    address public paymentRecipient;

    /// @notice is this payment token accepted?
    mapping(IERC20 paymentToken => AggregatorV3Interface oracle) public paymentTokenOracle;

    constructor(UsdPlus _usdplus, address _paymentRecipient, address initialOwner) Ownable(initialOwner) {
        if (address(_usdplus) == address(0)) revert ZeroAddress();
        if (_paymentRecipient == address(0)) revert ZeroAddress();

        usdplus = _usdplus;
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
        if (address(oracle) == address(0)) revert PaymentTokenNotAccepted();

        uint8 oracleDecimals = oracle.decimals();
        // slither-disable-next-line unused-return
        (, int256 price,,,) = oracle.latestRoundData();

        return Math.mulDiv(paymentTokenAmount, uint256(price), 10 ** uint256(oracleDecimals));
    }

    /// @notice mint USD+ for payment
    /// @param to recipient
    /// @param paymentToken payment token
    /// @param paymentTokenAmount amount of payment token to spend
    /// @return issued amount of USD+ minted
    function issue(address to, IERC20 paymentToken, uint256 paymentTokenAmount) external returns (uint256) {
        if (to == address(0)) revert ZeroAddress();
        if (paymentTokenAmount == 0) revert ZeroAmount();

        uint256 _issueAmount = previewIssueAmount(paymentToken, paymentTokenAmount);
        emit Issued(to, paymentToken, paymentTokenAmount, _issueAmount);

        paymentToken.safeTransferFrom(msg.sender, paymentRecipient, paymentTokenAmount);
        usdplus.mint(to, _issueAmount);

        return _issueAmount;
    }
}
