// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IUsdPlusRedeemer {
    struct PaymentTokenOracleInfo {
        AggregatorV3Interface oracle;
        uint256 heartbeat;
    }

    struct Request {
        address owner;
        address receiver;
        IERC20 paymentToken;
        uint256 paymentTokenAmount;
        uint256 usdplusAmount;
    }

    event PaymentTokenOracleSet(IERC20 indexed paymentToken, AggregatorV3Interface oracle, uint256 heartbeat);
    event L2SequencerOracleSet(address indexed l2SequencerOracle);
    event SequencerGracePeriodSet(uint256 sequencerGracePeriod);
    event RequestCreated(
        uint256 indexed ticket,
        address indexed receiver,
        IERC20 paymentToken,
        uint256 paymentTokenAmount,
        uint256 usdplusAmount
    );
    event RequestCancelled(uint256 indexed ticket, address indexed to);
    event RequestFulfilled(
        uint256 indexed ticket,
        address indexed receiver,
        IERC20 paymentToken,
        uint256 paymentTokenAmount,
        uint256 usdplusAmount
    );
    event RequestBurned(uint256 indexed ticket, address indexed receiver, uint256 usdplusAmount);
    event FundsRescued(address indexed to, uint256 amount);

    error PaymentTokenNotAccepted();
    error InvalidTicket();
    error UnauthorizedRedeemer();

    /// @notice USD+
    function usdplus() external view returns (address);

    /// @notice Oracle for payment token
    /// @param paymentToken payment token
    /// @dev address(0) if payment token not accepted
    function paymentTokenOracle(IERC20 paymentToken) external view returns (PaymentTokenOracleInfo memory oracle);

    /// @notice get request info
    /// @param ticket request ticket number
    function requests(uint256 ticket) external view returns (Request memory);

    /// @notice get next request ticket number
    function nextTicket() external view returns (uint256);

    /// @notice get oracle price for payment token
    /// @param paymentToken payment token
    function getOraclePrice(IERC20 paymentToken) external view returns (uint256 price, uint8 decimals);

    /// @notice calculate payment token amount received for burning USD+
    /// @param paymentToken payment token
    /// @param paymentTokenAmount amount of payment token
    function previewWithdraw(IERC20 paymentToken, uint256 paymentTokenAmount)
        external
        view
        returns (uint256 usdplusAmount);

    /// @notice create a request to burn USD+ for payment
    /// @param paymentToken payment token
    /// @param paymentTokenAmount amount of payment token
    /// @param receiver recipient
    /// @param owner USD+ owner
    /// @return ticket request ticket number
    /// @dev exchange rate fixed at time of request creation
    function requestWithdraw(IERC20 paymentToken, uint256 paymentTokenAmount, address receiver, address owner)
        external
        returns (uint256 ticket);

    /// @notice create a request to burn USD+ for payment
    /// @param paymentToken payment token
    /// @param paymentTokenAmount amount of payment token
    /// @param receiver recipient
    /// @param owner USD+ owner
    /// @param maxUsdplusAmount maximum amount of USD+ to burn
    /// @return ticket request ticket number
    /// @dev exchange rate fixed at time of request creation
    function requestWithdraw(
        IERC20 paymentToken,
        uint256 paymentTokenAmount,
        address receiver,
        address owner,
        uint256 maxUsdplusAmount
    ) external returns (uint256 ticket);

    /// @notice calculate payment token amount received for burning USD+
    /// @param paymentToken payment token
    /// @param usdplusAmount amount of USD+ to burn
    function previewRedeem(IERC20 paymentToken, uint256 usdplusAmount)
        external
        view
        returns (uint256 paymentTokenAmount);

    /// @notice create a request to burn USD+ for payment
    /// @param paymentToken payment token
    /// @param usdplusAmount amount of USD+ to burn
    /// @param receiver recipient
    /// @param owner USD+ owner
    /// @return ticket request ticket number
    /// @dev exchange rate fixed at time of request creation
    function requestRedeem(IERC20 paymentToken, uint256 usdplusAmount, address receiver, address owner)
        external
        returns (uint256 ticket);

    /// @notice create a request to burn USD+ for payment
    /// @param paymentToken payment token
    /// @param usdplusAmount amount of USD+ to burn
    /// @param receiver recipient
    /// @param owner USD+ owner
    /// @param minPaymentTokenAmount minimum amount of payment token to receive
    /// @return ticket request ticket number
    /// @dev exchange rate fixed at time of request creation
    function requestRedeem(
        IERC20 paymentToken,
        uint256 usdplusAmount,
        address receiver,
        address owner,
        uint256 minPaymentTokenAmount
    ) external returns (uint256 ticket);

    /// @notice Allows rescue of USD+ tokens that are stuck in the contract
    /// @dev CAUTION: Only rescue truly stuck funds. Ensure enough USD+ remains for pending redemptions
    /// @param to The address to send the rescued USD+ tokens to
    /// @param amount The amount of USD+ to rescue
    function rescueFunds(address to, uint256 amount) external;

    /// @notice fulfill a request to burn USD+ for payment
    /// @param ticket request ticket number
    function fulfill(uint256 ticket) external;

    /// @notice cancel a request to burn USD+ for payment
    /// @param ticket request ticket number
    function cancel(uint256 ticket) external;
}
