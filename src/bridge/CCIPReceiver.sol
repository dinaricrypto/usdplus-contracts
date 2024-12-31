// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAny2EVMMessageReceiver} from "ccip/contracts/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {Client} from "ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";

/// @title CCIPReceiver - Base contract for CCIP applications that can receive messages.
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/bridge/CCIPReceiver.sol)
/// @author Modified from Chainlink (https://github.com/smartcontractkit/ccip/blob/ccip-develop/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol)
abstract contract CCIPReceiver is IERC165, IAny2EVMMessageReceiver {
    /// ------------------ Types ------------------

    event RouterSet(address indexed router);

    error InvalidRouter(address router);

    /// ------------------ Storage ------------------

    struct CCIPReceiverStorage {
        address _router;
    }

    // keccak256(abi.encode(uint256(keccak256("dinaricrypto.storage.CCIPReceiver")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CCIPRECEIVER_STORAGE_LOCATION =
        0xedc444dd658271ef4a9c3fff333a6ab7abefccb2b01babad968042805dd76d00;

    function _getCCIPReceiverStorage() private pure returns (CCIPReceiverStorage storage $) {
        assembly {
            $.slot := CCIPRECEIVER_STORAGE_LOCATION
        }
    }

    /// ------------------ Initialization ------------------

    // slither-disable-next-line naming-convention
    function __CCIPReceiver_init(address router) internal {
        CCIPReceiverStorage storage $ = _getCCIPReceiverStorage();
        $._router = router;
    }

    function _setRouter(address router) internal {
        if (router == address(0)) revert InvalidRouter(address(0));
        CCIPReceiverStorage storage $ = _getCCIPReceiverStorage();
        $._router = router;
        emit RouterSet(router);
    }

    /// @inheritdoc IAny2EVMMessageReceiver
    function ccipReceive(Client.Any2EVMMessage calldata message) external virtual override onlyRouter {
        _ccipReceive(message);
    }

    /// @notice Override this function in your implementation.
    /// @param message Any2EVMMessage
    function _ccipReceive(Client.Any2EVMMessage calldata message) internal virtual;

    /////////////////////////////////////////////////////////////////////
    // Plumbing
    /////////////////////////////////////////////////////////////////////

    /// @notice Return the current router
    /// @return i_router address
    function getRouter() public view returns (address) {
        CCIPReceiverStorage storage $ = _getCCIPReceiverStorage();
        return $._router;
    }

    /// @dev only calls from the set router are accepted.
    modifier onlyRouter() {
        if (msg.sender != getRouter()) revert InvalidRouter(msg.sender);
        _;
    }
}
