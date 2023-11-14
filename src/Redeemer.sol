// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.23;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {UsdPlus} from "./UsdPlus.sol";
import {StakedUsdPlus} from "./StakedUsdPlus.sol";

/// @notice manages requests for USD+ burning
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/Redeemer.sol)
contract Redeemer is AccessControl {
    using SafeERC20 for IERC20;
    using SafeERC20 for UsdPlus;

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
    error PaymentTokenNotAccepted();
    error InvalidTicket();

    bytes32 public constant FULFILLER_ROLE = keccak256("FULFILLER_ROLE");

    /// @notice USD+
    UsdPlus public immutable usdplus;

    /// @notice stUSD+
    StakedUsdPlus public immutable stakedUsdplus;

    /// @notice is this payment token accepted?
    mapping(IERC20 => AggregatorV3Interface) public paymentTokenOracle;

    mapping(uint256 => Request) public requests;

    uint256 public nextTicket;

    constructor(StakedUsdPlus _stakedUsdplus, address initialOwner) {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);

        stakedUsdplus = _stakedUsdplus;
        usdplus = UsdPlus(_stakedUsdplus.asset());
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
    /// @param paymentToken payment token
    /// @param usdplusAmount amount of USD+
    function previewRedeem(IERC20 paymentToken, uint256 usdplusAmount) public view returns (uint256) {
        AggregatorV3Interface oracle = paymentTokenOracle[paymentToken];
        if (address(oracle) == address(0)) revert PaymentTokenNotAccepted();

        uint8 oracleDecimals = oracle.decimals();
        // slither-disable-next-line unused-return
        (, int256 price,,,) = oracle.latestRoundData();

        return Math.mulDiv(usdplusAmount, 10 ** uint256(oracleDecimals), uint256(price));
    }

    /// @notice calculate payment amount for stUSD+ unstake and USD+ burn
    /// @param paymentToken payment token
    /// @param stakedUsdplusAmount amount of stUSD+
    function previewUnstakeAndRedeem(IERC20 paymentToken, uint256 stakedUsdplusAmount)
        external
        view
        returns (uint256)
    {
        return previewRedeem(paymentToken, stakedUsdplus.previewRedeem(stakedUsdplusAmount));
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

        uint256 paymentAmount = previewRedeem(paymentToken, amount);
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
            usdplus.safeTransferFrom(owner, address(this), amount);
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
        usdplus.safeTransfer(_request.owner, _request.burnAmount);
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
    function unstakeAndRequest(address receiver, address owner, IERC20 paymentToken, uint256 amount)
        external
        returns (uint256 ticket)
    {
        uint256 _redeemAmount = stakedUsdplus.redeem(amount, address(this), owner);
        return request(receiver, address(this), paymentToken, _redeemAmount);
    }
}
