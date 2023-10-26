// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @notice stablecoin
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/UsdPlus.sol)
contract UsdPlus is ERC20Permit, AccessControl {
    event TreasurySet(address indexed treasury);

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @notice treasury for digital assets backing USD+
    address public treasury;

    constructor(address initialOwner) ERC20("USD+", "USD+") ERC20Permit("USD+") {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
    }

    // ------------------ Admin ------------------

    /// @notice set treasury address
    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        treasury = _treasury;
        emit TreasurySet(_treasury);
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

    // TODO: blacklist
}
