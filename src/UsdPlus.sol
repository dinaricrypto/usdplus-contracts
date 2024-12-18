// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {ERC20Rebasing} from "sbt-contracts/src/ERC20Rebasing.sol";
import {ERC7281Min, IERC7281Min} from "./ERC7281/ERC7281Min.sol";
import {ITransferRestrictor} from "./ITransferRestrictor.sol";

/// @notice stablecoin
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/UsdPlus.sol)
contract UsdPlus is UUPSUpgradeable, ERC20Rebasing, ERC7281Min, AccessControlDefaultAdminRulesUpgradeable {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// ------------------ Types ------------------

    event TreasurySet(address indexed treasury);
    event TransferRestrictorSet(ITransferRestrictor indexed transferRestrictor);
    /// @dev Emitted during rebase
    event BalancePerShareSet(uint256 balancePerShare);

    /// ------------------ Storage ------------------

    struct UsdPlusStorage {
        // treasury for digital assets backing USD+
        address _treasury;
        // transfer restrictor
        ITransferRestrictor _transferRestrictor;
        // Balance per share in ethers decimals
        uint128 _balancePerShare;
    }

    // keccak256(abi.encode(uint256(keccak256("dinaricrypto.storage.UsdPlus")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant USDPLUS_STORAGE_LOCATION =
        0x531780929781d75f94b208ae2c2a4530451c739f715a1a03bbbb934f354cbb00;

    function _getUsdPlusStorage() private pure returns (UsdPlusStorage storage $) {
        assembly {
            $.slot := USDPLUS_STORAGE_LOCATION
        }
    }

    /// ------------------ Initialization ------------------

    function initialize(address initialTreasury, ITransferRestrictor initialTransferRestrictor, address initialOwner)
        public
        initializer
    {
        __AccessControlDefaultAdminRules_init_unchained(0, initialOwner);

        UsdPlusStorage storage $ = _getUsdPlusStorage();
        $._treasury = initialTreasury;
        $._transferRestrictor = initialTransferRestrictor;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// ------------------ Getters ------------------

    /// @notice Token name
    function name() public pure override returns (string memory) {
        return "USD+";
    }

    /// @notice Token symbol
    function symbol() public pure override returns (string memory) {
        return "USD+";
    }

    /// @notice treasury for digital assets backing USD+
    function treasury() public view returns (address) {
        UsdPlusStorage storage $ = _getUsdPlusStorage();
        return $._treasury;
    }

    /// @notice transfer restrictor
    function transferRestrictor() public view returns (ITransferRestrictor) {
        UsdPlusStorage storage $ = _getUsdPlusStorage();
        return $._transferRestrictor;
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function checkTransferRestricted(address from, address to) public view {
        UsdPlusStorage storage $ = _getUsdPlusStorage();
        ITransferRestrictor _transferRestrictor = $._transferRestrictor;
        if (address(_transferRestrictor) != address(0)) {
            _transferRestrictor.requireNotRestricted(from, to);
        }
    }

    function isBlacklisted(address account) external view returns (bool) {
        UsdPlusStorage storage $ = _getUsdPlusStorage();
        ITransferRestrictor _transferRestrictor = $._transferRestrictor;
        if (address(_transferRestrictor) != address(0)) {
            return _transferRestrictor.isBlacklisted(account);
        }
        return false;
    }

    function balancePerShare() public view override returns (uint128) {
        UsdPlusStorage storage $ = _getUsdPlusStorage();
        uint128 _balancePerShare = $._balancePerShare;
        // Override with default if not set due to upgrade
        if (_balancePerShare == 0) return _INITIAL_BALANCE_PER_SHARE;
        return _balancePerShare;
    }

    // ------------------ Admin ------------------

    /// @notice set treasury address
    function setTreasury(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UsdPlusStorage storage $ = _getUsdPlusStorage();
        $._treasury = newTreasury;
        emit TreasurySet(newTreasury);
    }

    /// @notice set transfer restrictor
    function setTransferRestrictor(ITransferRestrictor newTransferRestrictor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        UsdPlusStorage storage $ = _getUsdPlusStorage();
        $._transferRestrictor = newTransferRestrictor;
        emit TransferRestrictorSet(newTransferRestrictor);
    }

    function setIssuerLimits(address issuer, uint256 mintingLimit, uint256 burningLimit)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _setIssuerLimits(issuer, mintingLimit, burningLimit);
    }

    // ------------------ Minting/Burning ------------------

    /// @inheritdoc IERC7281Min
    function mint(address to, uint256 value) external {
        _useMintingLimits(_msgSender(), value);
        _mint(to, value);
    }

    /// @inheritdoc IERC7281Min
    function burn(address from, uint256 value) external {
        address spender = _msgSender();
        if (from != spender) {
            _spendAllowance(from, spender, value);
        }

        _useBurningLimits(spender, value);
        _burn(from, value);
    }

    /// @notice burn USD+ from msg.sender
    function burn(uint256 value) external {
        address from = _msgSender();

        _useBurningLimits(from, value);
        _burn(from, value);
    }

    // ------------------ Rebasing ------------------

    /// @dev rounds towards intial value
    function rebaseAdd(uint128 value) external onlyRole(OPERATOR_ROLE) {
        uint256 _supply = totalSupply();
        uint128 _balancePerShare = uint128(FixedPointMathLib.fullMulDiv(balancePerShare(), _supply + value, _supply));
        UsdPlusStorage storage $ = _getUsdPlusStorage();
        $._balancePerShare = _balancePerShare;
        emit BalancePerShareSet(_balancePerShare);
    }

    function rebaseMul(uint128 factor) external onlyRole(OPERATOR_ROLE) {
        uint128 _balancePerShare = balancePerShare() * factor;
        UsdPlusStorage storage $ = _getUsdPlusStorage();
        $._balancePerShare = _balancePerShare;
        emit BalancePerShareSet(_balancePerShare);
    }

    /// @dev rounds towards intial value
    function rebaseSub(uint128 value) external onlyRole(OPERATOR_ROLE) {
        uint256 _supply = totalSupply();
        uint128 _balancePerShare = uint128(FixedPointMathLib.fullMulDivUp(balancePerShare(), _supply - value, _supply));
        UsdPlusStorage storage $ = _getUsdPlusStorage();
        $._balancePerShare = _balancePerShare;
        emit BalancePerShareSet(_balancePerShare);
    }

    // ------------------ Transfer Restriction ------------------

    function _beforeTokenTransfer(address from, address to, uint256) internal view override {
        checkTransferRestricted(from, to);
    }
}
