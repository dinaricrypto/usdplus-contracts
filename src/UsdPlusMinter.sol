// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

import {ControlledUpgradeable} from "./deployment/ControlledUpgradeable.sol";
import {IUsdPlusMinter} from "./IUsdPlusMinter.sol";
import {UsdPlus} from "./UsdPlus.sol";
import {SelfPermit, Permit} from "./SelfPermit.sol";

/// @notice USD+ minter
/// @dev If the payment token is USD+, the amount is forwarded to the receiver.
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/Minter.sol)
contract UsdPlusMinter is IUsdPlusMinter, ControlledUpgradeable, PausableUpgradeable, SelfPermit {
    /// ------------------ Types ------------------
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error ZeroAmount();
    error SlippageViolation();
    error InvalidPrice();
    error StalePrice();
    error SequencerDown();
    error SequencerGracePeriodNotOver();

    // Define the role identifier for the private minter role
    bytes32 public constant PRIVATE_MINTER_ROLE = keccak256("PRIVATE_MINTER_ROLE");

    /// ------------------ Storage ------------------

    struct UsdPlusMinterStorage {
        // USD+
        address _usdplus;
        // receiver of payment tokens
        address _paymentRecipient;
        // is this payment token accepted?
        mapping(IERC20 => PaymentTokenOracleInfo) _paymentTokenOracle;
        // is the L2 sequencer up?
        address _l2SequencerOracle;
        // grace period for the L2 sequencer startup
        uint256 _sequencerGracePeriod;
    }

    // keccak256(abi.encode(uint256(keccak256("dinaricrypto.storage.UsdPlusMinter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant USDPLUSMINTER_STORAGE_LOCATION =
        0xf45ed6bde210b9a0bc6994d3da3a58de9b4dab28125cb5a4981ed369bf01bc00;

    function _getUsdPlusMinterStorage() private pure returns (UsdPlusMinterStorage storage $) {
        assembly {
            $.slot := USDPLUSMINTER_STORAGE_LOCATION
        }
    }

    /// ------------------ Initialization ------------------

    function initialize(address usdPlus, address initialPaymentRecipient, address initialOwner, address upgrader)
        public
        reinitializer(version())
    {
        __ControlledUpgradeable_init(initialOwner, upgrader);
        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        $._usdplus = usdPlus;
        $._paymentRecipient = initialPaymentRecipient;
        $._l2SequencerOracle = address(0);
        $._sequencerGracePeriod = 3600;
    }

    function reinitialize(address upgrader) public reinitializer(version()) {
        grantRole(UPGRADER_ROLE, upgrader);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// ------------------ Getters ------------------

    /// @inheritdoc IUsdPlusMinter
    function usdplus() external view returns (address) {
        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        return $._usdplus;
    }

    /// @inheritdoc IUsdPlusMinter
    function paymentRecipient() external view returns (address) {
        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        return $._paymentRecipient;
    }

    /// @inheritdoc IUsdPlusMinter
    function paymentTokenOracle(IERC20 paymentToken) external view returns (PaymentTokenOracleInfo memory) {
        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        return $._paymentTokenOracle[paymentToken];
    }

    function version() public pure override returns (uint8) {
        return 1;
    }

    function publicVersion() public pure override returns (string memory) {
        return "1.0.0";
    }

    /// ------------------ Admin ------------------

    /// @notice set payment recipient
    function setPaymentRecipient(address newPaymentRecipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newPaymentRecipient == address(0)) revert ZeroAddress();

        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        $._paymentRecipient = newPaymentRecipient;
        emit PaymentRecipientSet(newPaymentRecipient);
    }

    /// @notice set payment token oracle
    /// @param paymentToken payment token
    /// @param oracle oracle address
    /// @param heartbeat heartbeat in seconds
    function setPaymentTokenOracle(IERC20 paymentToken, AggregatorV3Interface oracle, uint256 heartbeat)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        $._paymentTokenOracle[paymentToken] = PaymentTokenOracleInfo(oracle, heartbeat);
        emit PaymentTokenOracleSet(paymentToken, oracle, heartbeat);
    }

    /// @notice set L2 sequencer oracle
    /// @param l2SequencerOracle Chainlink L2 sequencer oracle
    function setL2SequencerOracle(address l2SequencerOracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        $._l2SequencerOracle = l2SequencerOracle;
        emit L2SequencerOracleSet(l2SequencerOracle);
    }

    /// @notice set grace period for the L2 sequencer startup
    /// @param sequencerGracePeriod grace period in seconds
    function setSequencerGracePeriod(uint256 sequencerGracePeriod) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        $._sequencerGracePeriod = sequencerGracePeriod;
        emit SequencerGracePeriodSet(sequencerGracePeriod);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // ------------------ Mint ------------------

    /// @inheritdoc IUsdPlusMinter
    function getOraclePrice(IERC20 paymentToken) public view returns (uint256, uint8) {
        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
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

    /// @inheritdoc IUsdPlusMinter
    function previewDeposit(IERC20 paymentToken, uint256 paymentTokenAmount) public view returns (uint256) {
        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        if (address(paymentToken) == $._usdplus) return paymentTokenAmount;

        (uint256 price, uint8 oracleDecimals) = getOraclePrice(paymentToken);

        uint8 paymentDecimals = 18;
        try IERC20Metadata(address(paymentToken)).decimals() returns (uint8 decimals) {
            paymentDecimals = decimals;
        } catch {}

        uint8 usdPlusDecimals = 6;
        try IERC20Metadata($._usdplus).decimals() returns (uint8 decimals) {
            usdPlusDecimals = decimals;
        } catch {}

        return Math.mulDiv(
            paymentTokenAmount,
            price * 10 ** usdPlusDecimals,
            10 ** (oracleDecimals + paymentDecimals),
            Math.Rounding.Floor
        );
    }

    /// @inheritdoc IUsdPlusMinter
    function deposit(IERC20 paymentToken, uint256 paymentTokenAmount, address receiver)
        public
        whenNotPaused
        returns (uint256 usdPlusAmount)
    {
        usdPlusAmount = deposit(paymentToken, paymentTokenAmount, receiver, 0);
    }

    /// @inheritdoc IUsdPlusMinter
    function deposit(IERC20 paymentToken, uint256 paymentTokenAmount, address receiver, uint256 minUsdPlusAmount)
        public
        whenNotPaused
        returns (uint256 usdPlusAmount)
    {
        if (receiver == address(0)) revert ZeroAddress();
        if (paymentTokenAmount == 0) revert ZeroAmount();

        usdPlusAmount = previewDeposit(paymentToken, paymentTokenAmount);
        if (usdPlusAmount == 0) revert ZeroAmount();
        if (usdPlusAmount < minUsdPlusAmount) revert SlippageViolation();

        _issue(paymentToken, paymentTokenAmount, usdPlusAmount, msg.sender, receiver);
    }

    function _issue(
        IERC20 paymentToken,
        uint256 paymentTokenAmount,
        uint256 usdPlusAmount,
        address spender,
        address receiver
    ) internal {
        emit Issued(receiver, paymentToken, paymentTokenAmount, usdPlusAmount);

        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        if (address(paymentToken) == $._usdplus) {
            paymentToken.safeTransferFrom(spender, receiver, paymentTokenAmount);
        } else {
            paymentToken.safeTransferFrom(spender, $._paymentRecipient, paymentTokenAmount);
            UsdPlus($._usdplus).mint(receiver, usdPlusAmount);
        }
    }

    /// @inheritdoc IUsdPlusMinter
    function previewMint(IERC20 paymentToken, uint256 usdPlusAmount) public view returns (uint256) {
        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        if (address(paymentToken) == $._usdplus) return usdPlusAmount;

        (uint256 price, uint8 oracleDecimals) = getOraclePrice(paymentToken);

        uint8 paymentDecimals = 18;
        try IERC20Metadata(address(paymentToken)).decimals() returns (uint8 decimals) {
            paymentDecimals = decimals;
        } catch {}

        uint8 usdPlusDecimals = 6;
        try IERC20Metadata($._usdplus).decimals() returns (uint8 decimals) {
            usdPlusDecimals = decimals;
        } catch {}

        return Math.mulDiv(
            usdPlusAmount, 10 ** (oracleDecimals + paymentDecimals), price * 10 ** usdPlusDecimals, Math.Rounding.Ceil
        );
    }

    /// @inheritdoc IUsdPlusMinter
    function mint(IERC20 paymentToken, uint256 usdPlusAmount, address receiver)
        public
        whenNotPaused
        returns (uint256 paymentTokenAmount)
    {
        paymentTokenAmount = mint(paymentToken, usdPlusAmount, receiver, type(uint256).max);
    }

    /// @inheritdoc IUsdPlusMinter
    function mint(IERC20 paymentToken, uint256 usdPlusAmount, address receiver, uint256 maxPaymentTokenAmount)
        public
        whenNotPaused
        returns (uint256 paymentTokenAmount)
    {
        if (receiver == address(0)) revert ZeroAddress();
        if (usdPlusAmount == 0) revert ZeroAmount();

        paymentTokenAmount = previewMint(paymentToken, usdPlusAmount);
        if (paymentTokenAmount == 0) revert ZeroAmount();
        if (paymentTokenAmount > maxPaymentTokenAmount) revert SlippageViolation();

        _issue(paymentToken, paymentTokenAmount, usdPlusAmount, msg.sender, receiver);
    }

    /// @notice Mint USD+ using a permit
    /// @param paymentToken The token to be spent
    /// @param permit The permit data
    /// @param signature The signature of the permit
    /// Misnomer: Behaves like deposit.
    function privateMint(IERC20 paymentToken, Permit calldata permit, bytes memory signature)
        external
        onlyRole(PRIVATE_MINTER_ROLE)
        returns (uint256 usdPlusAmount)
    {
        if (permit.value == 0) revert ZeroAmount();

        usdPlusAmount = previewDeposit(paymentToken, permit.value);
        if (usdPlusAmount == 0) revert ZeroAmount();

        if (signature.length != 65) revert ECDSA.ECDSAInvalidSignatureLength(signature.length);

        // Get v, r, s from signature
        // From OpenZeppelin's ECDSA.sol
        bytes32 r;
        bytes32 s;
        uint8 v;
        // ecrecover takes the signature parameters, and the only way to get them
        // currently is to use assembly.
        assembly ("memory-safe") {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        selfPermit(address(paymentToken), permit.owner, permit.value, permit.deadline, v, r, s);

        _issue(paymentToken, permit.value, usdPlusAmount, permit.owner, permit.owner);
    }
}
