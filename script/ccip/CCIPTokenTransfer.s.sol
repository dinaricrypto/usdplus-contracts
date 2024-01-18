// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {Client} from "ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract CCIPTokenTransfer is Script {
    struct Config {
        address deployer;
        IRouterClient ccipRouter;
        IERC20 ccipToken;
        uint64 dest;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");

        Config memory cfg = Config({
            deployer: vm.addr(deployerPrivateKey),
            ccipRouter: IRouterClient(vm.envAddress("CCIP_ROUTER")),
            ccipToken: IERC20(vm.envAddress("CCIP_TOKEN")),
            dest: uint64(vm.envUint("CCIP_DEST"))
        });

        uint256 amount = 10 ** 18;

        console.log("deployer: %s", cfg.deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        Client.EVM2AnyMessage memory message = _createCCIPMessage(address(cfg.ccipToken), cfg.deployer, amount);

        // approve
        cfg.ccipToken.approve(address(cfg.ccipRouter), amount);

        // get fee
        uint256 fee = cfg.ccipRouter.getFee(cfg.dest, message);

        // send to bridge
        bytes32 messageId = cfg.ccipRouter.ccipSend{value: fee}(cfg.dest, message);

        console.log("messageId");
        console.logBytes32(messageId);

        vm.stopBroadcast();
    }

    function _createCCIPMessage(address token, address to, uint256 amount)
        internal
        pure
        returns (Client.EVM2AnyMessage memory)
    {
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: token, amount: amount});

        return Client.EVM2AnyMessage({
            receiver: abi.encode(to),
            data: bytes(""),
            tokenAmounts: tokenAmounts,
            feeToken: address(0), // ETH will be used for fees
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit to 0 as we are not sending any data
                Client.EVMExtraArgsV1({gasLimit: 0})
                )
        });
    }
}
