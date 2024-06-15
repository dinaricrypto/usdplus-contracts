// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {UsdPlusMinter} from "./UsdPlusMinter.sol";
import {UsdPlus} from "./UsdPlus.sol";

contract UsdPlusPrivateMinter is UUPSUpgradeable, AccessControlDefaultAdminRulesUpgradeable {
    /// ------------------ Types ------------------
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error ZeroAmount();

    event Issued(
        address indexed receiver, IERC20 indexed paymentToken, uint256 paymentTokenAmount, uint256 usdPlusAmount
    );
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    struct Signature {
        uint256 deadline;
        bytes signature;
    }

    /// ------------------ Storage ------------------
    struct UsdPlusPrivateMinterStorage {
        address _usdplus;
        address _paymentToken;
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
    
    function initialize(address usdPlus, address _paymentToken, address initialOwner) public virtual initializer() {
        __AccessControlDefaultAdminRules_init_unchained(0, initialOwner);
        UsdPlusPrivateMinterStorage storage $ = _getUsdPlusPrivateMinterStorage();
        $._usdplus = usdPlus;
        $._paymentToken = _paymentToken;
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


    function getPaymentToken() external view returns (address) {
        return _getUsdPlusPrivateMinterStorage()._paymentToken;
    }

    function vault() external view returns (address) {
        return _getUsdPlusPrivateMinterStorage()._vault;
    }

    /// ------------------ Internal ------------------
    function _issue(IERC20 paymentToken, uint256 paymentTokenAmount, uint256 usdPlusAmount, address receiver)
        internal
    {
        emit Issued(receiver, paymentToken, paymentTokenAmount, usdPlusAmount);

        UsdPlusPrivateMinterStorage storage $ = _getUsdPlusPrivateMinterStorage();
        paymentToken.safeTransferFrom(msg.sender, $._vault, paymentTokenAmount);
        UsdPlus($._usdplus).mint(receiver, usdPlusAmount);
    }
}