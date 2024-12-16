// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {IUsdPlusRedeemer} from "./IUsdPlusRedeemer.sol";
import {UsdPlus} from "./UsdPlus.sol";
import {SelfPermit} from "./SelfPermit.sol";

/// @notice manages requests for USD+ burning
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/Redeemer.sol)
// TODO: remove owner from redeem request calls
contract UsdPlusRedeemer is
    IUsdPlusRedeemer,
    UUPSUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    SelfPermit,
    PausableUpgradeable
{
    /// ------------------ Types ------------------
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error ZeroAmount();
    error SlippageViolation();
    error InvalidPrice();
    error StalePrice();
    error SequencerDown();
    error SequencerGracePeriodNotOver();

    bytes32 public constant FULFILLER_ROLE = keccak256("FULFILLER_ROLE");

    /// ------------------ Storage ------------------

    struct UsdPlusRedeemerStorage {
        // USD+
        address _usdplus;
        // is this payment token accepted?
        mapping(IERC20 => PaymentTokenOracleInfo) _paymentTokenOracle;
        // request ticket => request
        mapping(uint256 => Request) _requests;
        // next request ticket number
        uint256 _nextTicket;
        // L2 sequencer oracle
        address _l2SequencerOracle;
        // grace period for the L2 sequencer startup
        uint256 _sequencerGracePeriod;
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

    function initialize(address usdPlus, address initialOwner) public initializer {
        __AccessControlDefaultAdminRules_init_unchained(0, initialOwner);
        __Pausable_init();

        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        $._usdplus = usdPlus;
        $._nextTicket = 0;
        $._l2SequencerOracle = address(0);
        $._sequencerGracePeriod = 3600;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// ------------------ Getters ------------------

    /// @inheritdoc IUsdPlusRedeemer
    function usdplus() external view returns (address) {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        return $._usdplus;
    }

    /// @inheritdoc IUsdPlusRedeemer
    function paymentTokenOracle(IERC20 paymentToken) external view returns (PaymentTokenOracleInfo memory) {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        return $._paymentTokenOracle[paymentToken];
    }

    /// @inheritdoc IUsdPlusRedeemer
    function requests(uint256 ticket) external view returns (Request memory) {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        return $._requests[ticket];
    }

    /// @inheritdoc IUsdPlusRedeemer
    function nextTicket() external view returns (uint256) {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        return $._nextTicket;
    }

    /// ------------------ Admin ------------------

    /// @notice set payment token oracle
    /// @param payment payment token
    /// @param oracle oracle address
    /// @param heartbeat heartbeat in seconds
    function setPaymentTokenOracle(IERC20 payment, AggregatorV3Interface oracle, uint256 heartbeat)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        $._paymentTokenOracle[payment] = PaymentTokenOracleInfo(oracle, heartbeat);
        emit PaymentTokenOracleSet(payment, oracle, heartbeat);
    }

    /// @notice set L2 sequencer oracle
    /// @param l2SequencerOracle Chainlink L2 sequencer oracle
    function setL2SequencerOracle(address l2SequencerOracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        $._l2SequencerOracle = l2SequencerOracle;
        emit L2SequencerOracleSet(l2SequencerOracle);
    }

    /// @notice set grace period for the L2 sequencer startup
    /// @param sequencerGracePeriod grace period in seconds
    function setSequencerGracePeriod(uint256 sequencerGracePeriod) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        $._sequencerGracePeriod = sequencerGracePeriod;
        emit SequencerGracePeriodSet(sequencerGracePeriod);
    }

    /// @notice pause contract
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @notice unpause contract
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // ----------------- Requests -----------------

    /// @inheritdoc IUsdPlusRedeemer
    function getOraclePrice(IERC20 paymentToken) public view returns (uint256, uint8) {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        PaymentTokenOracleInfo memory oracle = $._paymentTokenOracle[paymentToken];
        if (address(oracle.oracle) == address(0)) revert PaymentTokenNotAccepted();

        // Make sure the L2 sequencer is up.
        address l2SequencerOracle = $._l2SequencerOracle;
        if (l2SequencerOracle != address(0)) {
            // slither-disable-next-line unused-return
            (, int256 isDown, uint256 startedAt,,) = AggregatorV3Interface($._l2SequencerOracle).latestRoundData();

            // isDown == 0: Sequencer is up
            // isDown == 1: Sequencer is down
            if (isDown == 1) {
                revert SequencerDown();
            }

            // Make sure the grace period has passed after the
            // sequencer is back up.
            uint256 timeSinceUp = block.timestamp - startedAt;
            if (timeSinceUp <= $._sequencerGracePeriod) {
                revert SequencerGracePeriodNotOver();
            }
        }

        // slither-disable-next-line unused-return
        (, int256 price,, uint256 updatedAt,) = oracle.oracle.latestRoundData();
        if (price == 0) revert InvalidPrice();
        if (oracle.heartbeat > 0 && block.timestamp - updatedAt > oracle.heartbeat) revert StalePrice();
        uint8 oracleDecimals = oracle.oracle.decimals();

        return (uint256(price), oracleDecimals);
    }

    /// @inheritdoc IUsdPlusRedeemer
    function previewWithdraw(IERC20 paymentToken, uint256 paymentTokenAmount) public view returns (uint256) {
        (uint256 price, uint8 oracleDecimals) = getOraclePrice(paymentToken);
        return Math.mulDiv(paymentTokenAmount, price, 10 ** uint256(oracleDecimals), Math.Rounding.Ceil);
    }

    /// @inheritdoc IUsdPlusRedeemer
    function requestWithdraw(
        IERC20 paymentToken,
        uint256 paymentTokenAmount,
        address receiver,
        address owner,
        uint256 maxUsdPlusAmount
    ) public whenNotPaused returns (uint256 ticket) {
        if (receiver == address(0)) revert ZeroAddress();
        if (paymentTokenAmount == 0) revert ZeroAmount();

        uint256 usdplusAmount = previewWithdraw(paymentToken, paymentTokenAmount);
        if (usdplusAmount == 0) revert ZeroAmount();
        if (usdplusAmount > maxUsdPlusAmount) revert SlippageViolation();

        return _request(paymentToken, paymentTokenAmount, usdplusAmount, receiver, owner);
    }

    /// @inheritdoc IUsdPlusRedeemer
    function rescueFunds(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        emit FundsRescued(to, amount);
        IERC20($._usdplus).safeTransfer(to, amount);
    }

    function _request(
        IERC20 paymentToken,
        uint256 paymentTokenAmount,
        uint256 usdplusAmount,
        address receiver,
        address owner
    ) internal returns (uint256 ticket) {
        if (msg.sender != owner) {
            revert UnauthorizedRedeemer();
        }

        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();

        unchecked {
            ticket = $._nextTicket++;
        }

        $._requests[ticket] = Request({
            owner: msg.sender,
            receiver: receiver,
            paymentToken: paymentToken,
            paymentTokenAmount: paymentTokenAmount,
            usdplusAmount: usdplusAmount
        });

        emit RequestCreated(ticket, receiver, paymentToken, paymentTokenAmount, usdplusAmount);

        IERC20($._usdplus).safeTransferFrom(msg.sender, address(this), usdplusAmount);

        UsdPlus($._usdplus).burn(address(this), usdplusAmount);
    }

    /// @inheritdoc IUsdPlusRedeemer
    function previewRedeem(IERC20 paymentToken, uint256 usdplusAmount) public view returns (uint256) {
        (uint256 price, uint8 oracleDecimals) = getOraclePrice(paymentToken);
        return Math.mulDiv(usdplusAmount, 10 ** uint256(oracleDecimals), price, Math.Rounding.Floor);
    }

    /// @inheritdoc IUsdPlusRedeemer
    function requestRedeem(
        IERC20 paymentToken,
        uint256 usdplusAmount,
        address receiver,
        address owner,
        uint256 minPaymentTokenAmount
    ) public whenNotPaused returns (uint256 ticket) {
        if (receiver == address(0)) revert ZeroAddress();
        if (usdplusAmount == 0) revert ZeroAmount();

        uint256 paymentTokenAmount = previewRedeem(paymentToken, usdplusAmount);
        if (paymentTokenAmount == 0) revert ZeroAmount();
        if (paymentTokenAmount < minPaymentTokenAmount) revert SlippageViolation();

        return _request(paymentToken, paymentTokenAmount, usdplusAmount, receiver, owner);
    }

    /// @inheritdoc IUsdPlusRedeemer
    function fulfill(uint256 ticket) external onlyRole(FULFILLER_ROLE) {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        Request memory request = $._requests[ticket];

        if (request.receiver == address(0)) revert InvalidTicket();

        delete $._requests[ticket];

        emit RequestFulfilled(
            ticket, request.receiver, request.paymentToken, request.paymentTokenAmount, request.usdplusAmount
        );
        request.paymentToken.safeTransferFrom(msg.sender, request.receiver, request.paymentTokenAmount);
    }

    /// @inheritdoc IUsdPlusRedeemer
    function cancel(uint256 ticket) external onlyRole(FULFILLER_ROLE) {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        Request memory request = $._requests[ticket];

        if (request.receiver == address(0)) revert InvalidTicket();

        delete $._requests[ticket];

        emit RequestCancelled(ticket, request.receiver);

        // return USD+ to requester
        UsdPlus($._usdplus).mint(request.owner, request.usdplusAmount);
    }

    /// @notice Fulfills request to burn USD+ without sending payment token
    /// @dev This is a special case for USD+ bridging and 0 payment redemption
    function burnRequest(uint256 ticket) external onlyRole(FULFILLER_ROLE) {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        Request memory request = $._requests[ticket];

        if (request.receiver == address(0)) revert InvalidTicket();

        delete $._requests[ticket];

        emit RequestBurned(ticket, request.receiver, request.usdplusAmount);
    }
}
