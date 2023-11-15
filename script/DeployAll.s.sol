// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {TransferRestrictor} from "../src/TransferRestrictor.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {StakedUsdPlus} from "../src/StakedUsdPlus.sol";
import {UsdPlusMinter} from "../src/UsdPlusMinter.sol";
import {Redeemer} from "../src/Redeemer.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployAllScript is Script {
    struct DeployConfig {
        address owner;
        address treasury;
        address redemptionFulfiller;
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
            redemptionFulfiller: vm.envAddress("FULFILLER"),
            usdc: IERC20(vm.envAddress("USDC")),
            paymentTokenOracle: AggregatorV3Interface(vm.envAddress("USDCORACLE"))
        });

        console.log("deployer: %s", deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        /// ------------------ usd+ ------------------

        TransferRestrictor transferRestrictor = new TransferRestrictor(cfg.owner);

        UsdPlus usdplusImpl = new UsdPlus();
        UsdPlus usdplus = UsdPlus(
            address(
                new ERC1967Proxy(address(usdplusImpl), abi.encodeCall(UsdPlus.initialize, (cfg.treasury, transferRestrictor, cfg.owner)))
            )
        );

        StakedUsdPlus stakedusdplusImpl = new StakedUsdPlus();
        StakedUsdPlus stakedusdplus = StakedUsdPlus(
            address(
                new ERC1967Proxy(address(stakedusdplusImpl), abi.encodeCall(StakedUsdPlus.initialize, (usdplus, cfg.owner)))
            )
        );

        /// ------------------ usd+ minter/redeemer ------------------

        UsdPlusMinter minterImpl = new UsdPlusMinter();
        UsdPlusMinter minter = UsdPlusMinter(
            address(
                new ERC1967Proxy(address(minterImpl), abi.encodeCall(UsdPlusMinter.initialize, (stakedusdplus, cfg.treasury, cfg.owner)))
            )
        );
        usdplus.grantRole(usdplus.MINTER_ROLE(), address(minter));
        minter.setPaymentTokenOracle(cfg.usdc, cfg.paymentTokenOracle);

        Redeemer redeemer = new Redeemer(
            stakedusdplus,
            cfg.owner
        );
        usdplus.grantRole(usdplus.BURNER_ROLE(), address(redeemer));
        redeemer.grantRole(redeemer.FULFILLER_ROLE(), cfg.redemptionFulfiller);
        redeemer.setPaymentTokenOracle(cfg.usdc, cfg.paymentTokenOracle);

        vm.stopBroadcast();
    }
}
