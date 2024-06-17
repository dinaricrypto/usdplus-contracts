// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IUsdPlusPrivateMinter {
    event Issued(
        address indexed receiver, IERC20 indexed paymentToken, uint256 paymentTokenAmount, uint256 usdPlusAmount
    );

    event VaultSet(address indexed vault);
    event PaymentTokenSet(address indexed paymentToken);

    struct Signature {
        bytes signature;
        uint256 deadline;
    }

    struct MintOrder {
        address tokenReceiver;
        uint256 paymentAmount;
    }

    struct MintRequest {
        uint256 mintId;
        uint64 deadline;
    }
}
