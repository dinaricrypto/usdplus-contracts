// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.23;

import {
    UUPSUpgradeable,
    Initializable
} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Ownable2StepUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import {IRouterClient} from "contracts-ccip/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "contracts-ccip/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "./CCIPReceiver.sol";
import {UsdPlus} from "../UsdPlus.sol";

/// @notice USD+ mint/burn bridge using CCIP
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/bridge/CCIPMinter.sol)
contract CCIPMinter is Initializable, UUPSUpgradeable, Ownable2StepUpgradeable, CCIPReceiver {
    /// ------------------ Types ------------------

    error InvalidCall(bytes4 selector);
    error InvalidSender(address sender);
    error InvalidReceiver(address receiver);
    error InsufficientFunds(uint256 value, uint256 fee);

    event ApprovedSenderSet(uint64 indexed sourceChainSelector, address indexed sender);
    event ApprovedReceiverSet(uint64 indexed destinationChainSelector, address indexed receiver);
    event Sent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address indexed receiver,
        uint256 amount,
        uint256 fee
    );
    event Received(
        bytes32 indexed messageId, uint64 indexed sourceChainSelector, address indexed sender, uint256 amount
    );

    /// ------------------ Storage ------------------

    struct CCIPMinterStorage {
        UsdPlus _usdplus;
        // sourceChainSelector => sender
        mapping(uint64 => address) _approvedSender;
        // destinationChainSelector => receiver
        mapping(uint64 => address) _approvedReceiver;
    }

    // keccak256(abi.encode(uint256(keccak256("dinaricrypto.storage.CCIPMinter")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant CCIPMinter_STORAGE_LOCATION =
        0x78c64de9b9dc0dfc8eacf934bc1fbd9289d8bc5c08666d7fa486b9fc8241ca00;

    function _getCCIPMinterStorage() private pure returns (CCIPMinterStorage storage $) {
        assembly {
            $.slot := CCIPMinter_STORAGE_LOCATION
        }
    }

    /// ------------------ Initialization ------------------

    function initialize(UsdPlus usdPlus, address router, address initialOwner) public initializer {
        __CCIPReceiver_init(router);
        __Ownable_init(initialOwner);

        CCIPMinterStorage storage $ = _getCCIPMinterStorage();
        $._usdplus = usdPlus;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /// ------------------ Getters ------------------

    function getFee(uint64 destinationChainSelector, address receiver, uint256 amount) public view returns (uint256) {
        return IRouterClient(getRouter()).getFee(destinationChainSelector, _createCCIPMessage(receiver, amount));
    }

    /// ------------------ Admin ------------------

    function setApprovedSender(uint64 sourceChainSelector, address sender) external onlyOwner {
        CCIPMinterStorage storage $ = _getCCIPMinterStorage();
        $._approvedSender[sourceChainSelector] = sender;
        emit ApprovedSenderSet(sourceChainSelector, sender);
    }

    function setApprovedReceiver(uint64 destinationChainSelector, address receiver) external onlyOwner {
        CCIPMinterStorage storage $ = _getCCIPMinterStorage();
        $._approvedReceiver[destinationChainSelector] = receiver;
        emit ApprovedReceiverSet(destinationChainSelector, receiver);
    }

    /// ------------------ CCIP ------------------

    function _ccipReceive(Client.Any2EVMMessage calldata message) internal override {
        bytes4 selector = bytes4(message.data[:4]);
        if (selector != UsdPlus.mint.selector) revert InvalidCall(selector);
        CCIPMinterStorage storage $ = _getCCIPMinterStorage();
        address sender = abi.decode(message.sender, (address));
        if (sender != $._approvedSender[message.sourceChainSelector]) {
            revert InvalidSender(sender);
        }

        (bool success,) = address($._usdplus).call(message.data);
        require(success);

        (, uint256 amount) = abi.decode(message.data[4:], (address, uint256));
        emit Received(message.messageId, message.sourceChainSelector, sender, amount);
    }

    function _createCCIPMessage(address receiver, uint256 amount)
        internal
        pure
        returns (Client.EVM2AnyMessage memory)
    {
        return Client.EVM2AnyMessage({
            receiver: abi.encode(receiver),
            data: abi.encodeCall(UsdPlus.mint, (receiver, amount)),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            feeToken: address(0), // ETH will be used for fees
            extraArgs: bytes("")
        });
    }

    function burnAndMint(uint64 destinationChainSelector, address receiver, uint256 amount)
        external
        payable
        returns (bytes32 messageId)
    {
        CCIPMinterStorage storage $ = _getCCIPMinterStorage();
        if (receiver != $._approvedReceiver[destinationChainSelector]) revert InvalidReceiver(receiver);

        uint256 fee = getFee(destinationChainSelector, receiver, amount);
        if (fee > msg.value) revert InsufficientFunds(msg.value, fee);

        $._usdplus.burnFrom(msg.sender, amount);

        Client.EVM2AnyMessage memory message = _createCCIPMessage(receiver, amount);
        messageId = IRouterClient(getRouter()).ccipSend{value: msg.value}(destinationChainSelector, message);

        emit Sent(messageId, destinationChainSelector, receiver, amount, fee);
    }
}
