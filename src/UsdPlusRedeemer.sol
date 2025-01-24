// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {ControlledUpgradeable} from "./deployment/ControlledUpgradeable.sol";
import {IUsdPlusRedeemer} from "./IUsdPlusRedeemer.sol";
import {UsdPlus} from "./UsdPlus.sol";
import {SelfPermit} from "./SelfPermit.sol";

/// @notice manages requests for USD+ burning
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/Redeemer.sol)
contract UsdPlusRedeemer is IUsdPlusRedeemer, ControlledUpgradeable, SelfPermit, PausableUpgradeable {
    /// ------------------ Types ------------------
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error ZeroAmount();

    bytes32 public constant FULFILLER_ROLE = keccak256("FULFILLER_ROLE");
    bytes32 public constant PROXY_ROLE = keccak256("PROXY_ROLE");

    /// ------------------ Storage ------------------

    struct UsdPlusRedeemerStorage {
        // USD+
        address _usdplus;
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

    function initialize(address usdPlus, address initialOwner, address upgrader) public reinitializer(version()) {
        __ControlledUpgradeable_init(initialOwner, upgrader);
        __Pausable_init();

        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        $._usdplus = usdPlus;
        $._nextTicket = 0;
    }

    function reinitialize(address upgrader) public reinitializer(version()) {
        grantRole(UPGRADER_ROLE, upgrader);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// ------------------ Getters ------------------

    /// @inheritdoc IUsdPlusRedeemer
    function usdplus() external view returns (address) {
        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();
        return $._usdplus;
    }

    /// @inheritdoc IUsdPlusRedeemer
    function paymentTokenOracle(IERC20 paymentToken) external view returns (AggregatorV3Interface) {
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

    function version() public pure override returns (uint8) {
        return 1;
    }

    function publicVersion() public pure override returns (string memory) {
        return "1.0.0";
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
        AggregatorV3Interface oracle = $._paymentTokenOracle[paymentToken];
        if (address(oracle) == address(0)) revert PaymentTokenNotAccepted();

        // slither-disable-next-line unused-return
        (, int256 price,,,) = oracle.latestRoundData();
        uint8 oracleDecimals = oracle.decimals();

        return (uint256(price), oracleDecimals);
    }

    /// @inheritdoc IUsdPlusRedeemer
    function previewWithdraw(IERC20 paymentToken, uint256 paymentTokenAmount) public view returns (uint256) {
        (uint256 price, uint8 oracleDecimals) = getOraclePrice(paymentToken);
        return Math.mulDiv(paymentTokenAmount, price, 10 ** uint256(oracleDecimals), Math.Rounding.Ceil);
    }

    /// @inheritdoc IUsdPlusRedeemer
    function requestWithdraw(IERC20 paymentToken, uint256 paymentTokenAmount, address receiver, address owner)
        public
        whenNotPaused
        returns (uint256 ticket)
    {
        if (receiver == address(0)) revert ZeroAddress();
        if (paymentTokenAmount == 0) revert ZeroAmount();

        uint256 usdplusAmount = previewWithdraw(paymentToken, paymentTokenAmount);
        if (usdplusAmount == 0) revert ZeroAmount();

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
        if (msg.sender != owner && !hasRole(PROXY_ROLE, msg.sender)) {
            revert UnauthorizedRedeemer();
        }

        UsdPlusRedeemerStorage storage $ = _getUsdPlusRedeemerStorage();

        unchecked {
            ticket = $._nextTicket++;
        }

        $._requests[ticket] = Request({
            owner: owner,
            receiver: receiver,
            paymentToken: paymentToken,
            paymentTokenAmount: paymentTokenAmount,
            usdplusAmount: usdplusAmount
        });

        emit RequestCreated(ticket, receiver, paymentToken, paymentTokenAmount, usdplusAmount);

        // slither-disable-next-line arbitrary-send-erc20
        IERC20($._usdplus).safeTransferFrom(owner, address(this), usdplusAmount);

        UsdPlus($._usdplus).burn(address(this), usdplusAmount);
    }

    /// @inheritdoc IUsdPlusRedeemer
    function previewRedeem(IERC20 paymentToken, uint256 usdplusAmount) public view returns (uint256) {
        (uint256 price, uint8 oracleDecimals) = getOraclePrice(paymentToken);
        return Math.mulDiv(usdplusAmount, 10 ** uint256(oracleDecimals), price, Math.Rounding.Floor);
    }

    /// @inheritdoc IUsdPlusRedeemer
    function requestRedeem(IERC20 paymentToken, uint256 usdplusAmount, address receiver, address owner)
        public
        whenNotPaused
        returns (uint256 ticket)
    {
        if (receiver == address(0)) revert ZeroAddress();
        if (usdplusAmount == 0) revert ZeroAmount();

        uint256 paymentTokenAmount = previewRedeem(paymentToken, usdplusAmount);
        if (paymentTokenAmount == 0) revert ZeroAmount();

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
