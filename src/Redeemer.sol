// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {UsdPlus} from "./UsdPlus.sol";
import {UsdPlusPlus} from "./UsdPlusPlus.sol";

/// @notice manages requests for USD+ burning
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/Redeemer.sol)
contract Redeemer is AccessControl {
    using SafeERC20 for IERC20;

    struct Request {
        address owner;
        address receiver;
        IERC20 paymentToken;
        uint256 paymentAmount;
        uint256 burnAmount;
    }

    event PaymentTokenOracleSet(IERC20 indexed paymentToken, AggregatorV3Interface oracle);
    event RequestCreated(
        uint256 indexed ticket, address indexed receiver, IERC20 paymentToken, uint256 paymentAmount, uint256 burnAmount
    );
    event RequestCancelled(uint256 indexed ticket, address indexed to);
    event RequestFulfilled(
        uint256 indexed ticket, address indexed receiver, IERC20 paymentToken, uint256 paymentAmount, uint256 burnAmount
    );

    error ZeroAddress();
    error ZeroAmount();
    error PaymentNotAccepted();
    error InvalidTicket();

    bytes32 public constant FULFILLER_ROLE = keccak256("FULFILLER_ROLE");

    /// @notice USD+
    UsdPlus public immutable usdplus;

    /// @notice stUSD+
    UsdPlusPlus public immutable usdplusplus;

    /// @notice is this payment token accepted?
    mapping(IERC20 => AggregatorV3Interface) public paymentTokenOracle;

    mapping(uint256 => Request) public requests;

    uint256 public nextTicket;

    constructor(UsdPlusPlus _usdplusplus, address initialOwner) {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);

        usdplusplus = _usdplusplus;
        usdplus = UsdPlus(_usdplusplus.asset());
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
    function previewRedemptionAmount(IERC20 payment, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface oracle = paymentTokenOracle[payment];
        if (address(oracle) == address(0)) revert PaymentNotAccepted();

        uint8 oracleDecimals = oracle.decimals();
        (, int256 price,,,) = oracle.latestRoundData();

        return Math.mulDiv(amount, 10 ** uint256(oracleDecimals), uint256(price));
    }

    /// @notice create a request to burn USD+ for payment token
    /// @param receiver recipient
    /// @param owner owner of USD+
    /// @param paymentToken payment token
    /// @param amount amount of USD+ to burn
    /// @return ticket request ticket number
    /// @dev exchange rate fixed at time of request creation
    function request(address receiver, address owner, IERC20 paymentToken, uint256 amount)
        public
        returns (uint256 ticket)
    {
        if (receiver == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        uint256 paymentAmount = previewRedemptionAmount(paymentToken, amount);
        if (paymentAmount == 0) revert ZeroAmount();

        unchecked {
            ticket = nextTicket++;
        }

        requests[ticket] = Request({
            owner: owner == address(this) ? msg.sender : owner,
            receiver: receiver,
            paymentToken: paymentToken,
            paymentAmount: paymentAmount,
            burnAmount: amount
        });

        emit RequestCreated(ticket, receiver, paymentToken, paymentAmount, amount);

        if (owner != address(this)) {
            usdplus.transferFrom(owner, address(this), amount);
        }
    }

    /// @notice cancel a request to burn USD+ for payment
    /// @param ticket request ticket number
    function cancel(uint256 ticket) external onlyRole(FULFILLER_ROLE) {
        Request memory _request = requests[ticket];

        if (_request.receiver == address(0)) revert InvalidTicket();

        delete requests[ticket];

        emit RequestCancelled(ticket, _request.receiver);

        // return USD+ to requester
        usdplus.transfer(_request.owner, _request.burnAmount);
    }

    /// @notice fulfill a request to burn USD+ for payment token
    /// @param ticket request ticket number
    function fulfill(uint256 ticket) external onlyRole(FULFILLER_ROLE) {
        Request memory _request = requests[ticket];

        if (_request.receiver == address(0)) revert InvalidTicket();

        delete requests[ticket];

        emit RequestFulfilled(
            ticket, _request.receiver, _request.paymentToken, _request.paymentAmount, _request.burnAmount
        );

        usdplus.burn(_request.burnAmount);
        _request.paymentToken.safeTransferFrom(msg.sender, _request.receiver, _request.paymentAmount);
    }

    /// @notice redeem stUSD+ and request USD+ redemption for payment token
    /// @param receiver recipient
    /// @param owner owner of stUSD+
    /// @param paymentToken payment token
    /// @param amount amount of stUSD+ to redeem
    /// @return ticket request ticket number
    function redeemAndRequest(address receiver, address owner, IERC20 paymentToken, uint256 amount) external returns (uint256 ticket) {
        uint256 _redeemAmount = usdplusplus.redeem(amount, address(this), owner);
        return request(receiver, address(this), paymentToken, _redeemAmount);
    }
}
