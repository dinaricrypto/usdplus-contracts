// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.23;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {UsdPlus} from "./UsdPlus.sol";
import {StakedUsdPlus} from "./StakedUsdPlus.sol";

/// @notice manages requests for USD+ burning
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/Redeemer.sol)
contract UsdPlusRedeemer is UUPSUpgradeable, AccessControlDefaultAdminRulesUpgradeable {
    /// ------------------ Types ------------------
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

    /// ------------------ Storage ------------------

    struct UsdPlusRedeemerStorage {
        // USD+
        UsdPlus _usdplus;
        // stUSD+
        StakedUsdPlus _stakedUsdplus;
        // is this payment token accepted?
        mapping(IERC20 => AggregatorV3Interface) _paymentTokenOracle;
        // request ticket => request
        mapping(uint256 => Request) _requests;
        // next request ticket number
        uint256 _nextTicket;
    }

    // keccak256(abi.encode(uint256(keccak256("dinaricrypto.storage.UsdPlusRedeemer")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant USDPLUSREDEEMER_STORAGE_LOCATION =
        0xf724d8e1327974c3212114feec241a18ecc4f13b9dce5898792083418cd99000;

    function _getUsdPlusRedeemerStorage() private pure returns (UsdPlusRedeemerStorage storage $) {
        assembly {
            $.slot := USDPLUSREDEEMER_STORAGE_LOCATION
        }
    }

    /// ------------------ Initialization ------------------

    function initialize(StakedUsdPlus initialStakedUsdplus, address initialOwner) public initializer {
        __AccessControlDefaultAdminRules_init_unchained(0, initialOwner);

        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        $._usdplus = UsdPlus(initialStakedUsdplus.asset());
        $._stakedUsdplus = initialStakedUsdplus;
        $._nextTicket = 0;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// ------------------ Getters ------------------

    /// @notice USD+
    function usdplus() external view returns (UsdPlus) {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        return $._usdplus;
    }

    /// @notice stUSD+
    function stakedUsdplus() external view returns (StakedUsdPlus) {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        return $._stakedUsdplus;
    }

    /// @notice Oracle for payment token
    /// @param paymentToken payment token
    /// @dev address(0) if payment token not accepted
    function paymentTokenOracle(IERC20 paymentToken) external view returns (AggregatorV3Interface) {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        return $._paymentTokenOracle[paymentToken];
    }

    /// @notice request ticket => request
    function requests(uint256 ticket) external view returns (Request memory) {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        return $._requests[ticket];
    }

    /// @notice next request ticket number
    function nextTicket() external view returns (uint256) {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        return $._nextTicket;
    }

    /// ------------------ Admin ------------------

    /// @notice set payment token oracle
    /// @param payment payment token
    /// @param oracle oracle
    function setPaymentTokenOracle(IERC20 payment, AggregatorV3Interface oracle)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        $._paymentTokenOracle[payment] = oracle;
        emit PaymentTokenOracleSet(payment, oracle);
    }

    /// ----------------- Requests -----------------

    /// @notice calculate payment amount for USD+ burn
    /// @param paymentToken payment token
    /// @param usdplusAmount amount of USD+
    function previewRedeem(IERC20 paymentToken, uint256 usdplusAmount) public view returns (uint256) {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        AggregatorV3Interface oracle = $._paymentTokenOracle[paymentToken];
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
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        return previewRedeem(paymentToken, $._stakedUsdplus.previewRedeem(stakedUsdplusAmount));
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

        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        unchecked {
            ticket = $._nextTicket++;
        }

        $._requests[ticket] = Request({
            owner: owner == address(this) ? msg.sender : owner,
            receiver: receiver,
            paymentToken: paymentToken,
            paymentAmount: paymentAmount,
            burnAmount: amount
        });

        emit RequestCreated(ticket, receiver, paymentToken, paymentAmount, amount);

        if (owner != address(this)) {
            $._usdplus.safeTransferFrom(owner, address(this), amount);
        }
    }

    /// @notice cancel a request to burn USD+ for payment
    /// @param ticket request ticket number
    function cancel(uint256 ticket) external onlyRole(FULFILLER_ROLE) {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        Request memory _request = $._requests[ticket];

        if (_request.receiver == address(0)) revert InvalidTicket();

        delete $._requests[ticket];

        emit RequestCancelled(ticket, _request.receiver);

        // return USD+ to requester
        $._usdplus.safeTransfer(_request.owner, _request.burnAmount);
    }

    /// @notice fulfill a request to burn USD+ for payment token
    /// @param ticket request ticket number
    function fulfill(uint256 ticket) external onlyRole(FULFILLER_ROLE) {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        Request memory _request = $._requests[ticket];

        if (_request.receiver == address(0)) revert InvalidTicket();

        delete $._requests[ticket];

        emit RequestFulfilled(
            ticket, _request.receiver, _request.paymentToken, _request.paymentAmount, _request.burnAmount
        );

        $._usdplus.burn(_request.burnAmount);
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
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        uint256 _redeemAmount = $._stakedUsdplus.redeem(amount, address(this), owner);
        return request(receiver, address(this), paymentToken, _redeemAmount);
    }
}
