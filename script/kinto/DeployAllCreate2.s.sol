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

contract DeployAllCreate2 is Script {

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address treasury = vm.envAddress("TREASURY");

        console.log("deployer: %s", deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        /// ------------------ usd+ ------------------
        
        // TransferRestrictor transferRestrictor = new TransferRestrictor{ salt: keccak256("TransferRestrictor") }(deployer);
        TransferRestrictor transferRestrictor = TransferRestrictor(0x92ebC5eD28C78E18bFE37A4761d1b6Ec5997d979);

        UsdPlus usdplusImpl = new UsdPlus{ salt: keccak256("UsdPlus1") }();
        UsdPlus usdplus = UsdPlus(
            address(
                new ERC1967Proxy{ salt: keccak256("UsdPlusProxy") }(
                    address(usdplusImpl),
                    abi.encodeCall(UsdPlus.initialize, (treasury, transferRestrictor, deployer))
                )
            )
        );

        WrappedUsdPlus wrappedusdplusImpl = new WrappedUsdPlus{ salt: keccak256("WrappedUsdPlus1") }();
        WrappedUsdPlus wrappedusdplus = WrappedUsdPlus(
            address(
                new ERC1967Proxy{ salt: keccak256("WrappedUsdPlusProxy") }(
                    address(wrappedusdplusImpl),
                    abi.encodeCall(WrappedUsdPlus.initialize, (address(usdplus), deployer))
                )
            )
        );

        /// ------------------ usd+ minter/redeemer ------------------

        // UsdPlusMinter minterImpl = new UsdPlusMinter();
        // UsdPlusMinter minter = UsdPlusMinter(
        //     address(
        //         new ERC1967Proxy(
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
