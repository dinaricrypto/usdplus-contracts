// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Permit} from "./SelfPermit.sol";

interface IUsdPlusMinter {
    event PaymentRecipientSet(address indexed paymentRecipient);
    event PaymentTokenOracleSet(IERC20 indexed paymentToken, AggregatorV3Interface oracle);
    event L2SequencerOracleSet(address indexed l2SequencerOracle);
    event SequencerGracePeriodSet(uint256 sequencerGracePeriod);
    event Issued(
        address indexed receiver, IERC20 indexed paymentToken, uint256 paymentTokenAmount, uint256 usdPlusAmount
    );

    error PaymentTokenNotAccepted();

    /// @notice USD+
    function usdplus() external view returns (address);

    /// @notice receiver of payment tokens
    function paymentRecipient() external view returns (address);

    /// @notice Oracle for payment token
    /// @param paymentToken payment token
    /// @dev address(0) if payment token not accepted
    function paymentTokenOracle(IERC20 paymentToken) external view returns (AggregatorV3Interface oracle);

    /// @notice get oracle price for payment token
    /// @param paymentToken payment token
    function getOraclePrice(IERC20 paymentToken) external view returns (uint256 price, uint8 decimals);

    /// @notice calculate USD+ amount to mint for payment
    /// @param paymentToken payment token
    /// @param paymentTokenAmount amount of payment token
    function previewDeposit(IERC20 paymentToken, uint256 paymentTokenAmount)
        external
        view
        returns (uint256 usdPlusAmount);

    /// @notice mint USD+ for payment
    /// @param paymentToken payment token
    /// @param paymentTokenAmount amount of payment token to spend
    /// @param receiver recipient
    /// @param minUsdPlusAmount minimum amount of USD+ to mint
    /// @return usdPlusAmount amount of USD+ minted
    function deposit(IERC20 paymentToken, uint256 paymentTokenAmount, address receiver, uint256 minUsdPlusAmount)
        external
        returns (uint256 usdPlusAmount);

    /// @notice calculate the payment token amount to spend to mint USD+
    /// @param paymentToken payment token
    /// @param usdPlusAmount amount of USD+ to mint
    function previewMint(IERC20 paymentToken, uint256 usdPlusAmount)
        external
        view
        returns (uint256 paymentTokenAmount);

    /// @notice mint USD+ for payment
    /// @param paymentToken payment token
    /// @param usdPlusAmount amount of USD+ to mint
    /// @param receiver recipient
    /// @param maxPaymentTokenAmount maximum amount of payment token to spend
    /// @return paymentTokenAmount amount of payment token spent
    function mint(IERC20 paymentToken, uint256 usdPlusAmount, address receiver, uint256 maxPaymentTokenAmount)
        external
        returns (uint256 paymentTokenAmount);
}
