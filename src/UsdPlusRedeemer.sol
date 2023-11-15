// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.23;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {IUsdPlusRedeemer} from "./IUsdPlusRedeemer.sol";
import {UsdPlus} from "./UsdPlus.sol";
import {StakedUsdPlus} from "./StakedUsdPlus.sol";

/// @notice manages requests for USD+ burning
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/Redeemer.sol)
contract UsdPlusRedeemer is IUsdPlusRedeemer, AccessControl {
    using SafeERC20 for IERC20;
    using SafeERC20 for UsdPlus;

    error ZeroAddress();
    error ZeroAmount();

    bytes32 public constant FULFILLER_ROLE = keccak256("FULFILLER_ROLE");

    /// @notice USD+
    UsdPlus public immutable usdplus;

    /// @notice stUSD+
    StakedUsdPlus public immutable stakedUsdplus;

    /// @notice is this payment token accepted?
    mapping(IERC20 => AggregatorV3Interface) public paymentTokenOracle;

    mapping(uint256 => Request) _requests;

    uint256 public nextTicket;

    constructor(StakedUsdPlus _stakedUsdplus, address initialOwner) {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);

        stakedUsdplus = _stakedUsdplus;
        usdplus = UsdPlus(_stakedUsdplus.asset());
    }

    /// @inheritdoc IUsdPlusRedeemer
    function requests(uint256 ticket) external view override returns (Request memory) {
        return _requests[ticket];
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

    /// @inheritdoc IUsdPlusRedeemer
    function getOraclePrice(IERC20 paymentToken) public view returns (uint256, uint8) {
        AggregatorV3Interface oracle = paymentTokenOracle[paymentToken];
        if (address(oracle) == address(0)) revert PaymentTokenNotAccepted();

        // slither-disable-next-line unused-return
        (, int256 price,,,) = oracle.latestRoundData();
        uint8 oracleDecimals = oracle.decimals();

        return (uint256(price), oracleDecimals);
    }

    /// @inheritdoc IUsdPlusRedeemer
    function previewWithdraw(IERC20 paymentToken, uint256 paymentTokenAmount) public view returns (uint256) {
        (uint256 price, uint8 oracleDecimals) = getOraclePrice(paymentToken);
        return Math.mulDiv(paymentTokenAmount, price, 10 ** uint256(oracleDecimals));
    }

    /// @inheritdoc IUsdPlusRedeemer
    function requestWithdraw(IERC20 paymentToken, uint256 paymentTokenAmount, address receiver, address owner)
        public
        returns (uint256 ticket)
    {
        if (receiver == address(0)) revert ZeroAddress();
        if (paymentTokenAmount == 0) revert ZeroAmount();

        uint256 usdplusAmount = previewWithdraw(paymentToken, paymentTokenAmount);
        if (usdplusAmount == 0) revert ZeroAmount();

        return _request(paymentToken, paymentTokenAmount, usdplusAmount, receiver, owner);
    }

    function _request(
        IERC20 paymentToken,
        uint256 paymentTokenAmount,
        uint256 usdplusAmount,
        address receiver,
        address owner
    ) internal returns (uint256 ticket) {
        unchecked {
            ticket = nextTicket++;
        }

        _requests[ticket] = Request({
            owner: owner == address(this) ? msg.sender : owner,
            receiver: receiver,
            paymentToken: paymentToken,
            paymentTokenAmount: paymentTokenAmount,
            usdplusAmount: usdplusAmount
        });

        emit RequestCreated(ticket, receiver, paymentToken, paymentTokenAmount, usdplusAmount);

        if (owner != address(this)) {
            usdplus.safeTransferFrom(owner, address(this), usdplusAmount);
        }
    }

    /// @inheritdoc IUsdPlusRedeemer
    function previewRedeem(IERC20 paymentToken, uint256 usdplusAmount) public view returns (uint256) {
        (uint256 price, uint8 oracleDecimals) = getOraclePrice(paymentToken);
        return Math.mulDiv(usdplusAmount, 10 ** uint256(oracleDecimals), price);
    }

    /// @inheritdoc IUsdPlusRedeemer
    function requestRedeem(IERC20 paymentToken, uint256 usdplusAmount, address receiver, address owner)
        public
        returns (uint256 ticket)
    {
        if (receiver == address(0)) revert ZeroAddress();
        if (usdplusAmount == 0) revert ZeroAmount();

        uint256 paymentTokenAmount = previewRedeem(paymentToken, usdplusAmount);
        if (paymentTokenAmount == 0) revert ZeroAmount();

        return _request(paymentToken, paymentTokenAmount, usdplusAmount, receiver, owner);
    }

    /// @inheritdoc IUsdPlusRedeemer
    function previewUnstakeAndRedeem(IERC20 paymentToken, uint256 stakedUsdplusAmount)
        external
        view
        returns (uint256)
    {
        return previewRedeem(paymentToken, stakedUsdplus.previewRedeem(stakedUsdplusAmount));
    }

    /// @inheritdoc IUsdPlusRedeemer
    function unstakeAndRequestRedeem(IERC20 paymentToken, uint256 stakedUsdplusAmount, address receiver, address owner)
        external
        returns (uint256 ticket)
    {
        uint256 usdplusAmount = stakedUsdplus.redeem(stakedUsdplusAmount, address(this), owner);
        return requestRedeem(paymentToken, usdplusAmount, receiver, address(this));
    }

    /// @inheritdoc IUsdPlusRedeemer
    function fulfill(uint256 ticket) external onlyRole(FULFILLER_ROLE) {
        Request memory request = _requests[ticket];

        if (request.receiver == address(0)) revert InvalidTicket();

        delete _requests[ticket];

        emit RequestFulfilled(
            ticket, request.receiver, request.paymentToken, request.paymentTokenAmount, request.usdplusAmount
        );

        usdplus.burn(request.usdplusAmount);
        request.paymentToken.safeTransferFrom(msg.sender, request.receiver, request.paymentTokenAmount);
    }

    /// @inheritdoc IUsdPlusRedeemer
    function cancel(uint256 ticket) external onlyRole(FULFILLER_ROLE) {
        Request memory request = _requests[ticket];

        if (request.receiver == address(0)) revert InvalidTicket();

        delete _requests[ticket];

        emit RequestCancelled(ticket, request.receiver);

        // return USD+ to requester
        usdplus.safeTransfer(request.owner, request.usdplusAmount);
    }
}
