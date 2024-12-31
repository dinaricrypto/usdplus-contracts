// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {
    UUPSUpgradeable,
    Initializable
} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRouterClient} from "ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver, IERC165, IAny2EVMMessageReceiver} from "./CCIPReceiver.sol";
import {
    ControlledUpgradeable, AccessControlDefaultAdminRulesUpgradeable
} from "../deployment/ControlledUpgradeable.sol";

/// @notice USD+ mint/burn bridge using CCIP
/// Send and receive USD+ from other chains using CCIP
/// Mint/burn happens on a separate CCIP token pool contract
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/bridge/CCIPWaypoint.sol)
contract CCIPWaypoint is Initializable, ControlledUpgradeable, PausableUpgradeable, CCIPReceiver {
    // TODO: Generalize to include payment tokens: USDC, etc.
    // TODO: Migrate ccip dependency to official release. Needs fix to forge install (https://github.com/foundry-rs/foundry/issues/5996)
    using Address for address;
    using SafeERC20 for IERC20;

    /// ------------------ Types ------------------

    struct BridgeParams {
        address to;
    }

    error InvalidTransfer();
    error InvalidSender(uint64 sourceChainSelector, address sender);
    error InvalidReceiver(uint64 destinationChainSelector);
    error InsufficientFunds(uint256 value, uint256 fee);
    error AmountZero();
    error AddressZero();

    event ApprovedSenderSet(uint64 indexed sourceChainSelector, address indexed sourceChainWaypoint);
    event ApprovedReceiverSet(uint64 indexed destinationChainSelector, address indexed destinationChainWaypoint);
    event Sent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address indexed destinationChainWaypoint,
        address to,
        uint256 amount,
        uint256 fee
    );
    event Received(
        bytes32 indexed messageId,
        uint64 indexed sourceChainSelector,
        address indexed sourceChainWaypoint,
        address to,
        uint256 amount
    );

    /// ------------------ Storage ------------------

    struct CCIPWaypointStorage {
        // sourceChainSelector => sourceChainWaypoint
        mapping(uint64 => address) _approvedSender;
        // destinationChainSelector => destinationChainWaypoint
        mapping(uint64 => address) _approvedReceiver;
        address _usdplus;
    }

    // keccak256(abi.encode(uint256(keccak256("dinaricrypto.storage.CCIPWaypoint")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CCIPWAYPOINT_STORAGE_LOCATION =
        0x78c64de9b9dc0dfc8eacf934bc1fbd9289d8bc5c08666d7fa486b9fc8241ca00;

    function _getCCIPWaypointStorage() private pure returns (CCIPWaypointStorage storage $) {
        assembly {
            $.slot := CCIPWAYPOINT_STORAGE_LOCATION
        }
    }

    /// ------------------ Initialization ------------------

    function initialize(
        address usdPlus,
        address router,
        address initialOwner,
        address upgrader,
        string memory newVersion
    ) public initializer {
        __CCIPReceiver_init(router);
        __ControlledUpgradeable_init(initialOwner, upgrader, newVersion);
        __Pausable_init();

        CCIPWaypointStorage storage $ = _getCCIPWaypointStorage();
        $._usdplus = usdPlus;
    }

    function reinitialize(address initialOwner, address upgrader, string memory newVersion) external reinitializer(2) {
        __ControlledUpgradeable_init(initialOwner, upgrader, newVersion);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// ------------------ Getters ------------------

    function getApprovedSender(uint64 sourceChainSelector) external view returns (address) {
        CCIPWaypointStorage storage $ = _getCCIPWaypointStorage();
        return $._approvedSender[sourceChainSelector];
    }

    function getApprovedReceiver(uint64 destinationChainSelector) external view returns (address) {
        CCIPWaypointStorage storage $ = _getCCIPWaypointStorage();
        return $._approvedReceiver[destinationChainSelector];
    }

    function getFee(uint64 destinationChainSelector, address destinationChainWaypoint, address to, uint256 amount)
        public
        view
        returns (uint256)
    {
        return IRouterClient(getRouter()).getFee(
            destinationChainSelector, _createCCIPMessage(destinationChainWaypoint, to, amount)
        );
    }

    /// @notice IERC165 supports an interfaceId
    /// @param interfaceId The interfaceId to check
    /// @return true if the interfaceId is supported
    /// @dev Should indicate whether the contract implements IAny2EVMMessageReceiver
    /// e.g. return interfaceId == type(IAny2EVMMessageReceiver).interfaceId || interfaceId == type(IERC165).interfaceId
    /// This allows CCIP to check if ccipReceive is available before calling it.
    /// If this returns false or reverts, only tokens are transferred to the receiver.
    /// If this returns true, tokens are transferred and ccipReceive is called atomically.
    /// Additionally, if the receiver address does not have code associated with
    /// it at the time of execution (EXTCODESIZE returns 0), only tokens will be transferred.
    function supportsInterface(bytes4 interfaceId)
        public
        pure
        virtual
        override(IERC165, AccessControlDefaultAdminRulesUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IAny2EVMMessageReceiver).interfaceId || interfaceId == type(IERC165).interfaceId
            || interfaceId == type(AccessControlDefaultAdminRulesUpgradeable).interfaceId;
    }

    /// ------------------ Admin ------------------

    function setRouter(address router) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setRouter(router);
    }

    function setApprovedSender(uint64 sourceChainSelector, address sourceChainWaypoint)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        CCIPWaypointStorage storage $ = _getCCIPWaypointStorage();
        $._approvedSender[sourceChainSelector] = sourceChainWaypoint;
        emit ApprovedSenderSet(sourceChainSelector, sourceChainWaypoint);
    }

    function setApprovedReceiver(uint64 destinationChainSelector, address destinationChainWaypoint)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        CCIPWaypointStorage storage $ = _getCCIPWaypointStorage();
        $._approvedReceiver[destinationChainSelector] = destinationChainWaypoint;
        emit ApprovedReceiverSet(destinationChainSelector, destinationChainWaypoint);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /// ------------------ CCIP ------------------

    function _ccipReceive(Client.Any2EVMMessage calldata message) internal override {
        if (message.destTokenAmounts.length != 1) revert InvalidTransfer();
        CCIPWaypointStorage storage $ = _getCCIPWaypointStorage();
        address usdPlus = $._usdplus;
        if (message.destTokenAmounts[0].token != usdPlus) revert InvalidTransfer();
        address sender = abi.decode(message.sender, (address));
        if (sender != $._approvedSender[message.sourceChainSelector]) {
            revert InvalidSender(message.sourceChainSelector, sender);
        }

        BridgeParams memory params = abi.decode(message.data, (BridgeParams));
        uint256 amount = message.destTokenAmounts[0].amount;
        emit Received(message.messageId, message.sourceChainSelector, sender, params.to, amount);
        IERC20(usdPlus).safeTransfer(params.to, amount);
    }

    function _createCCIPMessage(address destinationChainWaypoint, address to, uint256 amount)
        internal
        view
        returns (Client.EVM2AnyMessage memory)
    {
        CCIPWaypointStorage storage $ = _getCCIPWaypointStorage();
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address($._usdplus), amount: amount});

        return Client.EVM2AnyMessage({
            receiver: abi.encode(destinationChainWaypoint),
            data: abi.encode(BridgeParams({to: to})),
            tokenAmounts: tokenAmounts,
            feeToken: address(0), // ETH will be used for fees
            extraArgs: bytes("")
        });
    }

    function sendUsdPlus(uint64 destinationChainSelector, address to, uint256 amount)
        external
        payable
        whenNotPaused
        returns (bytes32 messageId)
    {
        if (amount == 0) revert AmountZero();

        CCIPWaypointStorage storage $ = _getCCIPWaypointStorage();
        address destinationChainWaypoint = $._approvedReceiver[destinationChainSelector];
        if (destinationChainWaypoint == address(0)) revert InvalidReceiver(destinationChainSelector);

        // compile ccip message
        Client.EVM2AnyMessage memory message = _createCCIPMessage(destinationChainWaypoint, to, amount);

        // calculate and check fee
        address router = getRouter();
        uint256 fee = IRouterClient(router).getFee(destinationChainSelector, message);
        if (fee > msg.value) revert InsufficientFunds(msg.value, fee);

        // pull usdplus
        IERC20(message.tokenAmounts[0].token).safeTransferFrom(msg.sender, address(this), amount);

        // approve router to spend token
        IERC20(message.tokenAmounts[0].token).safeIncreaseAllowance(router, amount);

        // send ccip message
        messageId = IRouterClient(getRouter()).ccipSend{value: msg.value}(destinationChainSelector, message);

        // slither-disable-next-line reentrancy-events
        emit Sent(messageId, destinationChainSelector, destinationChainWaypoint, to, amount, fee);
    }

    /// ------------------ Rescue ------------------

    function rescue(address to, address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (to == address(0)) revert AddressZero();

        if (token == address(0)) {
            // slither-disable-next-line arbitrary-send-eth
            payable(to).transfer(amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }
}
