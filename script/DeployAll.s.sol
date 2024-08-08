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
        // Load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        bytes32 salt = keccak256(abi.encodePacked(deployer));

        DeployConfig memory cfg = DeployConfig({
            owner: deployer,
            treasury: vm.envAddress("TREASURY"),
            usdc: IERC20(vm.envAddress("USDC")),
            paymentTokenOracle: AggregatorV3Interface(vm.envAddress("USDCORACLE"))
        });

        console.log("deployer: %s", deployer);

        // Send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        /// ------------------ usdc ------------------
        // cfg.usdc = new ERC20Mock("USD Coin", "USDC", 6, cfg.owner);

        /// ------------------ usd+ ------------------
        TransferRestrictor transferRestrictor = new TransferRestrictor{salt: salt}(cfg.owner);

        UsdPlus usdplusImpl = new UsdPlus{salt: salt}();

        UsdPlus usdplus = UsdPlus(
            address(
                new ERC1967Proxy{salt: salt}(
                    address(usdplusImpl),
                    abi.encodeCall(UsdPlus.initialize, (cfg.treasury, transferRestrictor, cfg.owner))
                )
            )
        );

        WrappedUsdPlus wrappedusdplusImpl = new WrappedUsdPlus{salt: salt}();

        WrappedUsdPlus wrappedusdplus = WrappedUsdPlus(
            address(
                new ERC1967Proxy{salt: salt}(
                    address(wrappedusdplusImpl),
                    abi.encodeCall(WrappedUsdPlus.initialize, (address(usdplus), cfg.owner))
                )
            )
        );

        /// ------------------ usd+ minter/redeemer ------------------
        UsdPlusMinter minterImpl = new UsdPlusMinter{salt: salt}();

        UsdPlusMinter minter = UsdPlusMinter(
            address(
                new ERC1967Proxy{salt: salt}(
                    address(minterImpl),
                    abi.encodeCall(UsdPlusMinter.initialize, (address(usdplus), cfg.treasury, cfg.owner))
                )
            )
        );
        usdplus.setIssuerLimits(address(minter), type(uint256).max, 0);
        minter.setPaymentTokenOracle(cfg.usdc, cfg.paymentTokenOracle);

        UsdPlusRedeemer redeemerImpl = new UsdPlusRedeemer{salt: salt}();

        UsdPlusRedeemer redeemer = UsdPlusRedeemer(
            address(
                new ERC1967Proxy{salt: salt}(
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
