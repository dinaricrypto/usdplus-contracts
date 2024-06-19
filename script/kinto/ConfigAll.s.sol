// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {TransferRestrictor} from "../../src/TransferRestrictor.sol";
import {UsdPlus} from "../../src/UsdPlus.sol";
import {WrappedUsdPlus} from "../../src/WrappedUsdPlus.sol";
import {UsdPlusMinter} from "../../src/UsdPlusMinter.sol";
import {UsdPlusRedeemer} from "../../src/UsdPlusRedeemer.sol";
import {ERC20Mock} from "../../src/mocks/ERC20Mock.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ConfigAll is Script {
    struct Config {
        address rebaser;
        TransferRestrictor transferRestrictor;
        address restrictorAccount;
        UsdPlus usdplus;
        address usdc;
        address usdcOracle;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        Config memory cfg = Config({
            rebaser: vm.envAddress("REBASER"),
            transferRestrictor: TransferRestrictor(vm.envAddress("TRANSFER_RESTRICTOR")),
            restrictorAccount: vm.envAddress("RESTRICTOR_ACCOUNT"),
            usdplus: UsdPlus(vm.envAddress("USDPLUS")),
            usdc: vm.envAddress("USDC"),
            usdcOracle: vm.envAddress("USDC_ORACLE")
        });

        console.log("deployer: %s", deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        cfg.transferRestrictor.grantRole(cfg.transferRestrictor.RESTRICTOR_ROLE(), cfg.restrictorAccount);

        cfg.usdplus.grantRole(cfg.usdplus.OPERATOR_ROLE(), cfg.rebaser);
        // usdplus.setIssuerLimits(address(minter), type(uint256).max, 0);
        // usdplus.setIssuerLimits(address(redeemer), 0, type(uint256).max);

        /// ------------------ usd+ minter/redeemer ------------------

        // UsdPlusMinter minterImpl = new UsdPlusMinter{ salt: keccak256("UsdPlusMinter1") }();
        // UsdPlusMinter minter = UsdPlusMinter(
        //     address(
        //         new ERC1967Proxy{ salt: keccak256("UsdPlusMinterProxy") }(
        //             address(minterImpl),
        //             abi.encodeCall(UsdPlusMinter.initialize, (address(usdplus), treasury, deployer))
        //         )
        //     )
        // );
        // usdplus.setIssuerLimits(address(minter), type(uint256).max, 0);
        // minter.setPaymentTokenOracle(usdc, paymentTokenOracle);

        // UsdPlusRedeemer redeemerImpl = new UsdPlusRedeemer();
        // UsdPlusRedeemer redeemer = UsdPlusRedeemer(
        //     address(
        //         new ERC1967Proxy(
        //             address(redeemerImpl), abi.encodeCall(UsdPlusRedeemer.initialize, (address(usdplus), deployer))
        //         )
        //     )
        // );
        // usdplus.setIssuerLimits(address(redeemer), 0, type(uint256).max);
        // redeemer.grantRole(redeemer.FULFILLER_ROLE(), treasury);
        // redeemer.setPaymentTokenOracle(usdc, paymentTokenOracle);

        vm.stopBroadcast();
    }
}
