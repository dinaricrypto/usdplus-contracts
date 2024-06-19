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
        TransferRestrictor transferRestrictor;
        UsdPlus usdplus;
        UsdPlusMinter minter;
        UsdPlusRedeemer redeemer;
        address operator;
        address operator2;
        IERC20 usdc;
        // AggregatorV3Interface usdcOracle;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        Config memory cfg = Config({
            transferRestrictor: TransferRestrictor(vm.envAddress("TRANSFER_RESTRICTOR")),
            usdplus: UsdPlus(vm.envAddress("USDPLUS")),
            minter: UsdPlusMinter(vm.envAddress("MINTER")),
            redeemer: UsdPlusRedeemer(vm.envAddress("REDEEMER")),
            operator: vm.envAddress("OPERATOR"),
            operator2: vm.envAddress("OPERATOR2"),
            usdc: IERC20(vm.envAddress("USDC"))
            // usdcOracle: AggregatorV3Interface(vm.envAddress("USDC_ORACLE"))
        });

        console.log("deployer: %s", deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        // permissions to call
        // - restrict(address account)
        // - unrestrict(address account)
        cfg.transferRestrictor.grantRole(cfg.transferRestrictor.RESTRICTOR_ROLE(), cfg.operator);
        cfg.transferRestrictor.grantRole(cfg.transferRestrictor.RESTRICTOR_ROLE(), cfg.operator2);

        // permissions to call
        // - rebaseAdd(uint128 value)
        // - rebaseMul(uint128 factor)
        cfg.usdplus.grantRole(cfg.usdplus.OPERATOR_ROLE(), cfg.operator);
        cfg.usdplus.grantRole(cfg.usdplus.OPERATOR_ROLE(), cfg.operator2);
        // permissions to call
        // - mint(address to, uint256 value)
        cfg.usdplus.setIssuerLimits(address(cfg.minter), type(uint256).max, 0);
        // permissions to call
        // - burn(address from, uint256 value)
        // - burn(uint256 value)
        cfg.usdplus.setIssuerLimits(address(cfg.redeemer), 0, type(uint256).max);

        // cfg.minter.setPaymentTokenOracle(cfg.usdc, cfg.usdcOracle);

        // permissions to call
        // - fulfill(uint256 ticket)
        // - cancel(uint256 ticket)
        cfg.redeemer.grantRole(cfg.redeemer.FULFILLER_ROLE(), cfg.operator);
        cfg.redeemer.grantRole(cfg.redeemer.FULFILLER_ROLE(), cfg.operator2);
        // cfg.redeemer.setPaymentTokenOracle(cfg.usdc, cfg.usdcOracle);

        vm.stopBroadcast();
    }
}
