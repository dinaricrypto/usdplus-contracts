// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import {IRouterClient} from "ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "ccip/src/v0.8/ccip/libraries/Client.sol";
import {IAny2EVMMessageReceiver} from "ccip/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {IERC7281Min} from "../ERC7281/IERC7281Min.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract CCIPRouterMock is IRouterClient {
    using SafeERC20 for IERC20;

    function isChainSupported(uint64) external pure override returns (bool) {
        return true;
    }

    function getSupportedTokens(uint64) external pure override returns (address[] memory) {
        return new address[](0);
    }

    function getFee(uint64, Client.EVM2AnyMessage memory message) public pure override returns (uint256) {
        // truncate message hash
        return uint256(uint32(uint256(keccak256(abi.encode(message)))));
    }

    function getMessageId(Client.EVM2AnyMessage memory message) public pure returns (bytes32) {
        return keccak256(abi.encode(message));
    }

    function ccipSend(uint64, Client.EVM2AnyMessage calldata message) external payable override returns (bytes32) {
        uint256 feeTokenAmount = getFee(0, message);
        // address(0) signals payment in true native
        if (message.feeToken == address(0)) {
            // Ensure sufficient native.
            if (msg.value < feeTokenAmount) revert InsufficientFeeTokenAmount();
        } else {
            if (msg.value > 0) revert InvalidMsgValue();
            IERC20(message.feeToken).safeTransferFrom(msg.sender, address(this), feeTokenAmount);
        }

        // Burn tokens, mint tokens.
        address receiver = abi.decode(message.receiver, (address));
        for (uint256 i = 0; i < message.tokenAmounts.length; ++i) {
            IERC7281Min token = IERC7281Min(message.tokenAmounts[i].token);
            // slither-disable-next-line calls-loop
            token.burn(msg.sender, message.tokenAmounts[i].amount);
            // slither-disable-next-line calls-loop
            token.mint(receiver, message.tokenAmounts[i].amount);
        }

        // send message
        bytes32 messageId = getMessageId(message);
        Client.Any2EVMMessage memory sendMessage = Client.Any2EVMMessage({
            messageId: messageId,
            sourceChainSelector: uint64(block.chainid),
            sender: abi.encode(msg.sender),
            data: message.data,
            destTokenAmounts: message.tokenAmounts
        });

        IAny2EVMMessageReceiver(receiver).ccipReceive(sendMessage);

        return messageId;
    }
}
