// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/Script.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {UsdPlusPlus} from "../src/UsdPlusPlus.sol";
import {Minter} from "../src/Minter.sol";
import {Redeemer} from "../src/Redeemer.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract DeployAllScript is Script {
    struct DeployConfig {
        address owner;
        address treasury;
        address redemptionFulfiller;
        AggregatorV3Interface paymentTokenOracle;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOY_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        DeployConfig memory cfg = DeployConfig({
            owner: deployer,
            treasury: vm.envAddress("TREASURY"),
            redemptionFulfiller: vm.envAddress("FULFILLER"),
            paymentTokenOracle: AggregatorV3Interface(vm.envAddress("USDCORACLE"))
        });

        console.log("deployer: %s", deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        /// ------------------ payment token ------------------

        ERC20Mock usdc = new ERC20Mock("USD Coin - Dinari", "USDC", 6, cfg.owner);

        /// ------------------ usd+ ------------------

        UsdPlus usdplus = new UsdPlus(cfg.treasury, cfg.owner);

        new UsdPlusPlus(
            usdplus,
            cfg.owner
        );

        /// ------------------ usd+ minter/redeemer ------------------

        Minter minter = new Minter(
            usdplus,
            cfg.treasury,
            cfg.owner
        );
        usdplus.grantRole(usdplus.MINTER_ROLE(), address(minter));
        minter.setPaymentTokenOracle(usdc, cfg.paymentTokenOracle);

        Redeemer redeemer = new Redeemer(
            usdplus,
            cfg.owner
        );
        usdplus.grantRole(usdplus.BURNER_ROLE(), address(redeemer));
        redeemer.grantRole(redeemer.FULFILLER_ROLE(), cfg.redemptionFulfiller);
        redeemer.setPaymentTokenOracle(usdc, cfg.paymentTokenOracle);

        vm.stopBroadcast();
    }
}
