// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.23;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Ownable2StepUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {UsdPlus} from "./UsdPlus.sol";
import {StakedUsdPlus} from "./StakedUsdPlus.sol";

/// @notice USD+ minter
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/Minter.sol)
contract UsdPlusMinter is UUPSUpgradeable, Ownable2StepUpgradeable {
    /// ------------------ Types ------------------
    using SafeERC20 for IERC20;
    using SafeERC20 for UsdPlus;

    event PaymentRecipientSet(address indexed paymentRecipient);
    event PaymentTokenOracleSet(IERC20 indexed paymentToken, AggregatorV3Interface oracle);
    event Issued(address indexed receiver, IERC20 indexed paymentToken, uint256 paymentAmount, uint256 issueAmount);

    error ZeroAddress();
    error ZeroAmount();
    error PaymentTokenNotAccepted();

    /// ------------------ Storage ------------------

    struct UsdPlusMinterStorage {
        // USD+
        UsdPlus _usdplus;
        // stUSD+
        StakedUsdPlus _stakedUsdplus;
        // receiver of payment tokens
        address _paymentRecipient;
        // is this payment token accepted?
        mapping(IERC20 => AggregatorV3Interface) _paymentTokenOracle;
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

    function initialize(StakedUsdPlus initialStakedUsdplus, address initialPaymentRecipient, address initialOwner)
        public
        initializer
    {
        if (initialPaymentRecipient == address(0)) revert ZeroAddress();

        __Ownable_init(initialOwner);

        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        $._usdplus = UsdPlus(initialStakedUsdplus.asset());
        $._stakedUsdplus = initialStakedUsdplus;
        $._paymentRecipient = initialPaymentRecipient;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /// ------------------ Getters ------------------

    /// @notice USD+
    function usdplus() external view returns (UsdPlus) {
        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        return $._usdplus;
    }

    /// @notice stUSD+
    function stakedUsdplus() external view returns (StakedUsdPlus) {
        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        return $._stakedUsdplus;
    }

    /// @notice payment recipient
    function paymentRecipient() external view returns (address) {
        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        return $._paymentRecipient;
    }

    /// @notice Oracle for payment token
    /// @param paymentToken payment token
    /// @dev address(0) if payment token not accepted
    function paymentTokenOracle(IERC20 paymentToken) external view returns (AggregatorV3Interface) {
        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        return $._paymentTokenOracle[paymentToken];
    }

    /// ------------------ Admin ------------------

    /// @notice set payment recipient
    function setPaymentRecipient(address newPaymentRecipient) external onlyOwner {
        if (newPaymentRecipient == address(0)) revert ZeroAddress();

        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        $._paymentRecipient = newPaymentRecipient;
        emit PaymentRecipientSet(newPaymentRecipient);
    }

    /// @notice set payment token oracle
    /// @param paymentToken payment token
    /// @param oracle oracle
    function setPaymentTokenOracle(IERC20 paymentToken, AggregatorV3Interface oracle) external onlyOwner {
        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        $._paymentTokenOracle[paymentToken] = oracle;
        emit PaymentTokenOracleSet(paymentToken, oracle);
    }

    /// ------------------ Mint ------------------

    /// @notice calculate USD+ amount to mint for payment
    /// @param paymentToken payment token
    /// @param paymentTokenAmount amount of payment token
    function previewIssue(IERC20 paymentToken, uint256 paymentTokenAmount) public view returns (uint256) {
        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        AggregatorV3Interface oracle = $._paymentTokenOracle[paymentToken];
        if (address(oracle) == address(0)) revert PaymentTokenNotAccepted();

        uint8 oracleDecimals = oracle.decimals();
        // slither-disable-next-line unused-return
        (, int256 price,,,) = oracle.latestRoundData();

        return Math.mulDiv(paymentTokenAmount, uint256(price), 10 ** uint256(oracleDecimals));
    }

    /// @notice calculate stUSD+ amount to mint for payment
    /// @param paymentToken payment token
    /// @param paymentTokenAmount amount of payment token
    function previewIssueAndDeposit(IERC20 paymentToken, uint256 paymentTokenAmount) external view returns (uint256) {
        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        return $._stakedUsdplus.previewDeposit(previewIssue(paymentToken, paymentTokenAmount));
    }

    /// @notice mint USD+ for payment
    /// @param receiver recipient
    /// @param paymentToken payment token
    /// @param paymentTokenAmount amount of payment token to spend
    /// @return amount of USD+ minted
    function issue(address receiver, IERC20 paymentToken, uint256 paymentTokenAmount) public returns (uint256) {
        if (receiver == address(0)) revert ZeroAddress();
        if (paymentTokenAmount == 0) revert ZeroAmount();

        uint256 _issueAmount = previewIssue(paymentToken, paymentTokenAmount);
        emit Issued(receiver, paymentToken, paymentTokenAmount, _issueAmount);

        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        paymentToken.safeTransferFrom(msg.sender, $._paymentRecipient, paymentTokenAmount);
        $._usdplus.mint(receiver, _issueAmount);

        return _issueAmount;
    }

    /// @notice mint USD+ for payment and deposit in stUSD+
    /// @param receiver recipient
    /// @param paymentToken payment token
    /// @param paymentTokenAmount amount of payment token to spend
    /// @return amount of stUSD+ minted
    function issueAndDeposit(address receiver, IERC20 paymentToken, uint256 paymentTokenAmount)
        external
        returns (uint256)
    {
        uint256 _issueAmount = issue(address(this), paymentToken, paymentTokenAmount);
        UsdPlusMinterStorage storage $ = _getUsdPlusMinterStorage();
        StakedUsdPlus _stakedUsdplus = $._stakedUsdplus;
        $._usdplus.safeIncreaseAllowance(address(_stakedUsdplus), _issueAmount);
        return _stakedUsdplus.deposit(_issueAmount, receiver);
    }
}
