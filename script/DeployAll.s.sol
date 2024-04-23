// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {TransferRestrictor} from "../src/TransferRestrictor.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {WrappedUsdPlus} from "../src/WrappedUsdPlus.sol";
import {UsdPlusMinter} from "../src/UsdPlusMinter.sol";
import {UsdPlusRedeemer} from "../src/UsdPlusRedeemer.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployAll is Script {
    struct DeployConfig {
        address owner;
        address treasury;
        IERC20 usdc;
        AggregatorV3Interface paymentTokenOracle;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        DeployConfig memory cfg = DeployConfig({
            owner: deployer,
            treasury: vm.envAddress("TREASURY"),
            usdc: IERC20(vm.envAddress("USDC")),
            paymentTokenOracle: AggregatorV3Interface(vm.envAddress("USDCORACLE"))
        });

        console.log("deployer: %s", deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        /// ------------------ usdc ------------------

        // cfg.usdc = new ERC20Mock("USD Coin", "USDC", 6, cfg.owner);

        /// ------------------ usd+ ------------------

        TransferRestrictor transferRestrictor = new TransferRestrictor(cfg.owner);

        UsdPlus usdplusImpl = new UsdPlus();
        UsdPlus usdplus = UsdPlus(
            address(
                new ERC1967Proxy(
                    address(usdplusImpl),
                    abi.encodeCall(UsdPlus.initialize, (cfg.treasury, transferRestrictor, cfg.owner))
                )
            )
        );

        WrappedUsdPlus wrappedusdplusImpl = new WrappedUsdPlus();
        WrappedUsdPlus wrappedusdplus = WrappedUsdPlus(
            address(
                new ERC1967Proxy(
                    address(wrappedusdplusImpl),
                    abi.encodeCall(WrappedUsdPlus.initialize, (address(usdplus), cfg.owner))
                )
            )
        );

        /// ------------------ usd+ minter/redeemer ------------------

        UsdPlusMinter minterImpl = new UsdPlusMinter();
        UsdPlusMinter minter = UsdPlusMinter(
            address(
                new ERC1967Proxy(
                    address(minterImpl),
                    abi.encodeCall(UsdPlusMinter.initialize, (address(usdplus), cfg.treasury, cfg.owner))
                )
            )
        );
        usdplus.setIssuerLimits(address(minter), type(uint256).max, 0);
        minter.setPaymentTokenOracle(cfg.usdc, cfg.paymentTokenOracle);

        UsdPlusRedeemer redeemerImpl = new UsdPlusRedeemer();
        UsdPlusRedeemer redeemer = UsdPlusRedeemer(
            address(
                new ERC1967Proxy(
                    address(redeemerImpl), abi.encodeCall(UsdPlusRedeemer.initialize, (address(usdplus), cfg.owner))
                )
            )
        );
        usdplus.setIssuerLimits(address(redeemer), 0, type(uint256).max);
        redeemer.grantRole(redeemer.FULFILLER_ROLE(), cfg.treasury);
        redeemer.setPaymentTokenOracle(cfg.usdc, cfg.paymentTokenOracle);

        vm.stopBroadcast();
    }
}
