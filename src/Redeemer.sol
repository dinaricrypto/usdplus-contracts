// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {UsdPlus} from "./UsdPlus.sol";

/// @notice manages requests for USD+ burning
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/Redeemer.sol)
contract Redeemer is AccessControl, Nonces {
    using SafeERC20 for IERC20;

    struct Request {
        IERC20 paymentToken;
        uint256 burnAmount;
        uint256 paymentAmount;
    }

    event PaymentTokenOracleSet(IERC20 indexed paymentToken, AggregatorV3Interface oracle);
    event RequestCreated(
        address indexed to, uint256 indexed ticket, IERC20 paymentToken, uint256 burnAmount, uint256 paymentAmount
    );
    event RequestFulfilled(
        address indexed to, uint256 indexed ticket, IERC20 paymentToken, uint256 burnAmount, uint256 paymentAmount
    );

    error ZeroAddress();
    error ZeroAmount();
    error PaymentNotAccepted();
    error InvalidTicket();

    bytes32 public constant FULFILLER_ROLE = keccak256("FULFILLER_ROLE");

    /// @notice USD+
    UsdPlus public immutable usdplus;

    /// @notice is this payment token accepted?
    mapping(IERC20 => AggregatorV3Interface) public paymentTokenOracle;

    mapping(address => mapping(uint256 => Request)) public requests;

    // TODO: enumerable set of active requests?

    constructor(UsdPlus _usdplus, address initialOwner) {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);

        usdplus = _usdplus;
    }

    /// @notice set payment token oracle
    /// @param payment payment token
    /// @param oracle oracle
    function setPaymentTokenOracle(IERC20 payment, AggregatorV3Interface oracle)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        paymentTokenOracle[payment] = oracle;
        emit PaymentTokenOracleSet(payment, oracle);
    }

    // ----------------- Requests -----------------

    /// @notice calculate payment amount for USD+ burn
    /// @param payment payment token
    /// @param amount amount of USD+
    function redemptionAmount(IERC20 payment, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface oracle = paymentTokenOracle[payment];
        if (address(oracle) == address(0)) revert PaymentNotAccepted();

        uint8 oracleDecimals = oracle.decimals();
        (, int256 price,,,) = oracle.latestRoundData();

        return Math.mulDiv(amount, 10 ** uint256(oracleDecimals), uint256(price));
    }

    /// @notice create a request to burn USD+ for payment
    /// @param to recipient
    /// @param paymentToken payment token
    /// @param amount amount of USD+ to burn
    /// @return ticket recipient request ticket number
    /// @dev exchange rate fixed at time of request creation
    function request(address to, IERC20 paymentToken, uint256 amount) external returns (uint256 ticket) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 paymentAmount = redemptionAmount(paymentToken, amount);
        if (paymentAmount == 0) revert ZeroAmount();

        ticket = _useNonce(to);

        requests[to][ticket] = Request({paymentToken: paymentToken, burnAmount: amount, paymentAmount: paymentAmount});

        emit RequestCreated(to, ticket, paymentToken, amount, paymentAmount);

        usdplus.transferFrom(msg.sender, address(this), amount);
    }

    // TODO: cancel request - fulfiller role

    /// @notice fulfill a request to burn USD+ for payment
    /// @param to recipient
    /// @param ticket recipient request ticket number
    function fulfill(address to, uint256 ticket) external onlyRole(FULFILLER_ROLE) {
        Request memory _request = requests[to][ticket];

        if (_request.burnAmount == 0) revert InvalidTicket();

        delete requests[to][ticket];

        emit RequestFulfilled(to, ticket, _request.paymentToken, _request.burnAmount, _request.paymentAmount);

        usdplus.burn(_request.burnAmount);
        _request.paymentToken.safeTransferFrom(msg.sender, to, _request.paymentAmount);
    }
}
