// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IUsdPlusPrivateMinter} from "./IUsdPlusPrivateMinter.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {EIP712Upgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/cryptography/EIP712Upgradeable.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {SelfPermit} from "./common/SelfPermit.sol";
import {IUsdPlusMinter} from "./IUsdPlusMinter.sol";
import {UsdPlus} from "./UsdPlus.sol";

contract UsdPlusPrivateMinter is IUsdPlusPrivateMinter, EIP712Upgradeable, UUPSUpgradeable, AccessControlDefaultAdminRulesUpgradeable, SelfPermit {
    /// ------------------ Types ------------------
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error ZeroAmount();
    error ExpiredSignature();
    error InvalidSignature();

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant MINT_ORDER_HASH = keccak256("MintOrder(address tokenReceiver,uint256 amount)");
    bytes32 private constant MINT_REQUEST_HASH = keccak256("MintRequest(uint256 id,uint64 deadline)");

    /// ------------------ Storage ------------------
    struct UsdPlusPrivateMinterStorage {
        address _usdplus;
        address _initialPaymentToken;
        address _usdPlusMinter;
        address _vault;
    }

    // keccak256(abi.encode(uint256(keccak256("dinaricrypto.storage.UsdPlusPrivateMinter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant USDPLUSPRIVATEMINTER_STORAGE_LOCATION =
        0x4ebe58c3f8a789bedda2046518df42b95c3674b01c781c8a935b47ac6f49a700;

    function _getUsdPlusPrivateMinterStorage() private pure returns (UsdPlusPrivateMinterStorage storage $) {
        assembly {
            $.slot := USDPLUSPRIVATEMINTER_STORAGE_LOCATION
        }
    }

    /// ------------------ Initialization ------------------

    function initialize(address usdPlus, address _paymentToken, address initialOwner) public virtual initializer {
        __AccessControlDefaultAdminRules_init_unchained(0, initialOwner);
        UsdPlusPrivateMinterStorage storage $ = _getUsdPlusPrivateMinterStorage();
        $._usdplus = usdPlus;
        $._initialPaymentToken = _paymentToken;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// ------------------ Getters ------------------

    function usdplus() external view returns (address) {
        return _getUsdPlusPrivateMinterStorage()._usdplus;
    }

    function paymentToken() external view returns (address) {
        return _getUsdPlusPrivateMinterStorage()._initialPaymentToken;
    }

    function vault() external view returns (address) {
        return _getUsdPlusPrivateMinterStorage()._vault;
    }

    function previewDeposit(IERC20 _paymentToken, uint256 _paymentTokenAmount) public view returns (uint256) {
        UsdPlusPrivateMinterStorage storage $ = _getUsdPlusPrivateMinterStorage();
        (uint256 price, uint8 oracleDecimals) = IUsdPlusMinter($._usdPlusMinter).getOraclePrice(_paymentToken);
        return Math.mulDiv(_paymentTokenAmount, price, 10 ** uint256(oracleDecimals), Math.Rounding.Floor);
    }

    /// ------------------ Setters ------------------

    function setVault(address _newVault) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_newVault == address(0)) revert ZeroAddress();

        UsdPlusPrivateMinterStorage storage $ = _getUsdPlusPrivateMinterStorage();
        $._vault = _newVault;
        emit VaultSet(_newVault);
    }

    function setPaymentToken(address _newPaymentToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_newPaymentToken == address(0)) revert ZeroAddress();

        UsdPlusPrivateMinterStorage storage $ = _getUsdPlusPrivateMinterStorage();
        $._initialPaymentToken = _newPaymentToken;

        emit PaymentTokenSet(_newPaymentToken);
    }

    /// ------------------ Mint ------------------
    function mint(MintOrder calldata mintOrder, Signature calldata mintSignature) external onlyRole(MINTER_ROLE) {
        if (mintSignature.deadline < block.timestamp) revert ExpiredSignature();

        address requester = ECDSA.recover(
            _hashTypedDataV4(hashMintRequest(mintOrder, mintSignature.deadline)), mintSignature.signature
        );

        if (requester != msg.sender) revert InvalidSignature();

        UsdPlusPrivateMinterStorage storage $ = _getUsdPlusPrivateMinterStorage();

        uint256 usdPlusAmount = previewDeposit(IERC20($._initialPaymentToken), mintOrder.paymentAmount);

        _issue(IERC20($._initialPaymentToken), mintOrder.paymentAmount, usdPlusAmount, mintOrder.tokenReceiver);
    }

    function hashMintRequest(MintOrder calldata mintOrder, uint256 deadline) public pure returns (bytes32) {
        return keccak256(abi.encode(MINT_REQUEST_HASH, hashMintOrder(mintOrder), deadline));
    }

    function hashMintOrder(MintOrder calldata mintOrder) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(MINT_ORDER_HASH, mintOrder.tokenReceiver, mintOrder.paymentAmount)));
    }

    /// ------------------ Internal ------------------
    function _issue(IERC20 _paymentToken, uint256 _paymentTokenAmount, uint256 _usdPlusAmount, address _receiver)
        internal
    {
        emit Issued(_receiver, _paymentToken, _paymentTokenAmount, _usdPlusAmount);

        UsdPlusPrivateMinterStorage storage $ = _getUsdPlusPrivateMinterStorage();
        _paymentToken.safeTransferFrom(msg.sender, $._vault, _paymentTokenAmount);
        UsdPlus($._usdplus).mint(_receiver, _usdPlusAmount);
    }
}
