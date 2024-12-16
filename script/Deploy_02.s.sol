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

contract Deploy_02 is Script {
    struct DeployConfig {
        address owner;
        address treasury;
        IERC20 usdc;
        AggregatorV3Interface paymentTokenOracle;
        TransferRestrictor transferRestrictor;
        UsdPlus usdPlus;
        UsdPlusMinter minter;
        UsdPlusRedeemer redeemer;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        DeployConfig memory cfg = DeployConfig({
            owner: deployer,
            treasury: vm.envAddress("TREASURY"),
            usdc: IERC20(vm.envAddress("USDC")),
            paymentTokenOracle: AggregatorV3Interface(vm.envAddress("USDCORACLE")),
            transferRestrictor: TransferRestrictor(vm.envAddress("TRANSFERRESTRICTOR")),
            usdPlus: UsdPlus(vm.envAddress("USDPLUS")),
            minter: UsdPlusMinter(vm.envAddress("USDPLUS_MINTER")),
            redeemer: UsdPlusRedeemer(vm.envAddress("USDPLUS_REDEEMER"))
        });

        console.log("deployer: %s", deployer);

        address[4] memory holders = [
            // Sepolia
            // 0x764c37250DDD0D8f1f26b91d9c4FaE83c21fAE94,
            // 0x18Bef88D5b3dEa893E7A492fbC1a6379Cb42c8cC,
            // 0x0C07354Eb3E22aBb410a94b7b2caE4a8283A7623,
            // 0xB584B40f19aC35a55b8364F77A1c8703ded82126,
            // 0xF8797fE9A333b7744cB5D6A892Fc29E9bb54F22B,
            // 0x8f249c9CF607Dd7ea80658F3b55Be9e74E754a5f,
            // 0x9303a17F11459A0C0D5b59CE4bC3880269ec94b5,
            // 0x74C47044c021B01Cc036c524c0738DbbBBaCdD0F,
            // 0x4181803232280371E02a875F51515BE57B215231,
            // 0x0CD29C6196855eBF9dc4a0d3aD8D0b2137D908b0,
            // 0x09E365aCDB0d936DD250351aD0E7de3Dad8706E5,
            // 0xECC40Cf598B1e98846267F274559062aE4cd3F9D
            // Arbitrum Sepolia
            // 0x625390d982Ce375909dfa7C4c141dfE3d7b8AB50,
            // 0x764c37250DDD0D8f1f26b91d9c4FaE83c21fAE94,
            // 0x9bf747c2ABfd977BCA42Bdd60030a35593D7c38a,
            // 0xa0310CB0Ad4B59c32C4A81094dd6E574Ea8281C4
            // Arbitrum
            // 0x2855d241119Ce7Ad3ebeE690AC322a1cF03Ed46d,
            // 0x47910F43ecA6a2355E8b1Ff5F60923939FBB8915,
            // 0x4c3bD1Ac4F62F25388c02caf8e3e0D32d09Ff8B3,
            // 0x5C253d333D19C6A64c780D9ad5b5fe97a4a277BC,
            // 0x991cB35fc5F8328cd385c6fD4E4c8FcE6B57E471,
            // 0xAa0ed80DE46CF02bde4493A84FE22Af8fE79c01f,
            // 0xe9477d7C207eC0004Fc7D6221dbB6a29b8d18083
            // Ethereum
            0xe1B2FEEDE3ffE7e63a89A669A08688951c94611e,
            0x9583729A1ECa5fa337D8C05fBd02295B3d53b8F1,
            0x2855d241119Ce7Ad3ebeE690AC322a1cF03Ed46d,
            0x269e944aD9140fc6e21794e8eA71cE1AfBfe38c8
        ];

        uint256[] memory amounts = new uint256[](holders.length);
        for (uint256 i = 0; i < holders.length; i++) {
            amounts[i] = cfg.usdPlus.balanceOf(holders[i]);
        }

        console.log("balanceBefore: %s", amounts[0]);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        /// ------------------ usd+ ------------------

        UsdPlus usdPlusImpl = new UsdPlus();
        cfg.usdPlus.upgradeToAndCall(address(usdPlusImpl), "");

        WrappedUsdPlus wrappedusdplusImpl = new WrappedUsdPlus();
        WrappedUsdPlus wrappedusdplus = WrappedUsdPlus(
            address(
                new ERC1967Proxy(
                    address(wrappedusdplusImpl),
                    abi.encodeCall(WrappedUsdPlus.initialize, (address(cfg.usdPlus), cfg.owner))
                )
            )
        );

        // mint all tokens
        cfg.usdPlus.setIssuerLimits(deployer, type(uint256).max, type(uint256).max);
        for (uint256 i = 0; i < holders.length; i++) {
            cfg.usdPlus.mint(holders[i], amounts[i]);
        }

        console.log("balanceAfter: %s", cfg.usdPlus.balanceOf(holders[0]));

        /// ------------------ usd+ minter/redeemer ------------------

        cfg.minter.setPaymentTokenOracle(cfg.usdc, AggregatorV3Interface(address(0)), 0);
        cfg.redeemer.setPaymentTokenOracle(cfg.usdc, AggregatorV3Interface(address(0)), 0);
        cfg.redeemer.revokeRole(cfg.redeemer.FULFILLER_ROLE(), cfg.treasury);
        cfg.usdPlus.setIssuerLimits(address(cfg.minter), 0, 0);
        cfg.usdPlus.setIssuerLimits(address(cfg.redeemer), 0, 0);

        UsdPlusMinter minterImpl = new UsdPlusMinter();
        UsdPlusMinter minter = UsdPlusMinter(
            address(
                new ERC1967Proxy(
                    address(minterImpl),
                    abi.encodeCall(UsdPlusMinter.initialize, (address(cfg.usdPlus), cfg.treasury, cfg.owner))
                )
            )
        );
        cfg.usdPlus.setIssuerLimits(address(minter), type(uint256).max, 0);
        minter.setPaymentTokenOracle(cfg.usdc, cfg.paymentTokenOracle, 0);

        UsdPlusRedeemer redeemerImpl = new UsdPlusRedeemer();
        UsdPlusRedeemer redeemer = UsdPlusRedeemer(
            address(
                new ERC1967Proxy(
                    address(redeemerImpl), abi.encodeCall(UsdPlusRedeemer.initialize, (address(cfg.usdPlus), cfg.owner))
                )
            )
        );
        cfg.usdPlus.setIssuerLimits(address(redeemer), 0, type(uint256).max);
        redeemer.grantRole(redeemer.FULFILLER_ROLE(), cfg.treasury);
        redeemer.setPaymentTokenOracle(cfg.usdc, cfg.paymentTokenOracle, 0);

        vm.stopBroadcast();
    }
}
