// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ITransferRestrictor} from "./ITransferRestrictor.sol";

/// @notice stablecoin
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/UsdPlus.sol)
contract UsdPlus is ERC20Permit, AccessControl {
    event TreasurySet(address indexed treasury);
    event TransferRestrictorSet(ITransferRestrictor indexed transferRestrictor);

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @notice treasury for digital assets backing USD+
    address public treasury;

    ITransferRestrictor public transferRestrictor;

    constructor(address _treasury, ITransferRestrictor _transferRestrictor, address initialOwner)
        ERC20("USD+", "USD+")
        ERC20Permit("USD+")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        // slither-disable-next-line missing-zero-check
        treasury = _treasury;
        transferRestrictor = _transferRestrictor;
    }

    // ------------------ Admin ------------------

    /// @notice set treasury address
    function setTreasury(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // slither-disable-next-line missing-zero-check
        treasury = newTreasury;
        emit TreasurySet(newTreasury);
    }

    /// @notice set transfer restrictor
    function setTransferRestrictor(ITransferRestrictor newTransferRestrictor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        transferRestrictor = newTransferRestrictor;
        emit TransferRestrictorSet(newTransferRestrictor);
    }

    // ------------------ Minting/Burning ------------------

    /// @notice mint USD+ to account
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /// @notice burn USD+ from msg.sender
    function burn(uint256 value) external onlyRole(BURNER_ROLE) {
        _burn(_msgSender(), value);
    }

    /// @notice burn USD+ from account
    function burnFrom(address account, uint256 value) external onlyRole(BURNER_ROLE) {
        _spendAllowance(account, _msgSender(), value);
        _burn(account, value);
    }

    // ------------------ Transfer Restriction ------------------

    function _update(address from, address to, uint256 value) internal virtual override {
        checkTransferRestricted(from, to);

        super._update(from, to, value);
    }

    function checkTransferRestricted(address from, address to) public view {
        ITransferRestrictor _transferRestrictor = transferRestrictor;
        if (address(_transferRestrictor) != address(0)) {
            _transferRestrictor.requireNotRestricted(from, to);
        }
    }

    function isBlacklisted(address account) external view returns (bool) {
        ITransferRestrictor _transferRestrictor = transferRestrictor;
        if (address(_transferRestrictor) != address(0)) {
            return _transferRestrictor.isBlacklisted(account);
        }
        return false;
    }
}
