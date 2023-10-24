// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

import {UsdPlus} from "./USD+.sol";

/// @notice manages requests for USD+ burning
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/Redeemer.sol)
contract Redeemer is Ownable, Nonces {
    // TODO: oracle
    using SafeERC20 for IERC20;

    struct Request {
        uint256 amount;
        IERC20 payment;
    }

    event PaymentSet(IERC20 payment, bool status);
    event RequestCreated(address indexed to, uint256 indexed nonce, uint256 amount, IERC20 payment);
    event RequestFulfilled(address indexed to, uint256 indexed nonce, uint256 amount, IERC20 payment);

    error ZeroAddress();
    error ZeroAmount();
    error PaymentNotAccepted();
    error InvalidNonce();

    /// @notice USD+
    UsdPlus public immutable usdplus;

    /// @notice is this payment token accepted?
    mapping(IERC20 => bool) public acceptedPayment;

    mapping(address => mapping(uint256 => Request)) public requests;

    // TODO: enumerable set of active requests?

    constructor(UsdPlus _usdplus, address initialOwner) Ownable(initialOwner) {
        usdplus = _usdplus;
    }

    /// @notice set payment token status
    /// @param payment payment token
    /// @param status status
    function setPayment(IERC20 payment, bool status) external onlyOwner {
        acceptedPayment[payment] = status;
        emit PaymentSet(payment, status);
    }

    // ----------------- Requests -----------------

    /// @notice create a request to burn USD+ for payment
    /// @param to recipient
    /// @param amount amount of USD+ to burn
    /// @param payment payment token
    function request(address to, uint256 amount, IERC20 payment) external returns (uint256 nonce) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (!acceptedPayment[payment]) revert PaymentNotAccepted();

        nonce = _useNonce(to);

        requests[to][nonce] = Request({amount: amount, payment: payment});

        emit RequestCreated(to, nonce, amount, payment);

        usdplus.transferFrom(msg.sender, address(this), amount);
    }

    /// @notice fulfill a request to burn USD+ for payment
    /// @param to recipient
    /// @param nonce request nonce
    function fulfill(address to, uint256 nonce) external {
        Request memory _request = requests[to][nonce];

        if (_request.amount == 0) revert InvalidNonce();

        delete requests[to][nonce];

        emit RequestFulfilled(to, nonce, _request.amount, _request.payment);

        usdplus.burn(_request.amount);
        _request.payment.safeTransferFrom(msg.sender, to, _request.amount);
    }
}
