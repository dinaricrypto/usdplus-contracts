// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {UsdPlus} from "./USD+.sol";

/// @notice the one and only, manages requests for USD+ burning
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/Redeemer.sol)
contract Redeemer is Ownable {
    // TODO: events
    // TODO: request/fulfill system
    using SafeERC20 for IERC20;

    error PaymentNotAccepted();

    /// @notice USD+
    UsdPlus public immutable usdplus;

    /// @notice is this payment token accepted?
    mapping(IERC20 => bool) public acceptedPayment;

    constructor(UsdPlus _usdplus, address initialOwner) Ownable(initialOwner) {
        usdplus = _usdplus;
    }

    /// @notice set payment token status
    /// @param payment payment token
    /// @param status status
    function setPayment(IERC20 payment, bool status) external onlyOwner {
        acceptedPayment[payment] = status;
    }

    /// @notice burn USD+ for payment
    /// @param to recipient
    /// @param amount amount of USD+ to burn
    /// @param payment payment token
    function redeem(address to, uint256 amount, IERC20 payment) external {
        if (!acceptedPayment[payment]) revert PaymentNotAccepted();

        usdplus.burnFrom(msg.sender, amount);
        payment.safeTransfer(to, amount);
    }
}
