// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {UsdPlus} from "./USD+.sol";

/// @notice 1:1 stablecoin minter
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/onetoone_minter.sol)
contract OneToOneMinter is Ownable {
    using SafeERC20 for IERC20;

    error PaymentNotAccepted();

    /// @notice USD+
    UsdPlus public usdplus;

    /// @notice is this payment token accepted?
    mapping(IERC20 => bool) public acceptedPayment;

    constructor(UsdPlus _usdplus, address initialOwner) Ownable(initialOwner) {
        usdplus = _usdplus;
    }

    /// @notice add payment token
    /// @param payment payment token
    function addPayment(IERC20 payment) external onlyOwner {
        acceptedPayment[payment] = true;
    }

    /// @notice mint USD+ for payment
    /// @param to recipient
    /// @param amount amount of USD+ to mint
    /// @param payment payment token
    function issue(address to, uint256 amount, IERC20 payment) external {
        if (!acceptedPayment[payment]) revert PaymentNotAccepted();

        payment.safeTransferFrom(msg.sender, address(this), amount);
        usdplus.mint(to, amount);
    }
}
