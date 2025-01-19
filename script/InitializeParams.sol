// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

library InitializeParams {
    struct BaseInitializeParams {
        address initialOwner;
        address upgrader;
        string version;
    }

    struct UsdPlusInitializeParams {
        address initialTreasury;
        address initialTransferRestrictor;
        address initialOwner;
        address upgrader;
        string version;
    }

    struct CCIPWaypointInitializeParams {
        address usdPlus;
        address router;
        address initialOwner;
        address upgrader;
        string version;
    }

    struct UsdPlusMinterInitializeParams {
        address usdPlus;
        address initialPaymentRecipient;
        address initialOwner;
        address upgrader;
        string version;
    }

    struct UsdPlusRedeemerInitializeParams {
        address usdPlus;
        address initialOwner;
        address upgrader;
        string version;
    }

    struct WrappedUsdPlusInitializeParams {
        address usdplus;
        address initialOwner;
        address upgrader;
        string version;
    }

    struct TransferRestrictorInitializeParams {
        address initialOwner;
        address upgrader;
        string version;
    }
}
