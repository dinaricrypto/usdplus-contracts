// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import {ERC20Permit, ERC20} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract ERC20Mock is ERC20Permit, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint8 private immutable _decimals;

    constructor(string memory name_, string memory symbol_, uint8 decimals_, address initialOwner)
        ERC20(name_, symbol_)
        ERC20Permit(name_)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, initialOwner);
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

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
