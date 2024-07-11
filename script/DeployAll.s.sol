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
    error ContractDeploymentFailed();

    struct DeployConfig {
        address owner;
        address treasury;
        IERC20 usdc;
        AggregatorV3Interface paymentTokenOracle;
    }

    struct ImplementationBytecodes {
        bytes transferRestrictorBytecode;
        bytes usdplusImplBytecode;
        bytes wrappedusdplusImplBytecode;
        bytes minterImplBytecode;
        bytes redeemerImplBytecode;
    }

    function run() external {
        // load env variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        bytes32 salt = keccak256(abi.encodePacked(deployer));

        DeployConfig memory cfg = DeployConfig({
            owner: deployer,
            treasury: vm.envAddress("TREASURY"),
            usdc: IERC20(vm.envAddress("USDC")),
            paymentTokenOracle: AggregatorV3Interface(vm.envAddress("USDCORACLE"))
        });

        ImplementationBytecodes memory implBytecodes = ImplementationBytecodes({
            transferRestrictorBytecode: abi.encodePacked(type(TransferRestrictor).creationCode, abi.encode(cfg.owner)),
            usdplusImplBytecode: type(UsdPlus).creationCode,
            wrappedusdplusImplBytecode: type(WrappedUsdPlus).creationCode,
            minterImplBytecode: type(UsdPlusMinter).creationCode,
            redeemerImplBytecode: type(UsdPlusRedeemer).creationCode
        });

        console.log("deployer: %s", deployer);

        // send txs as deployer
        vm.startBroadcast(deployerPrivateKey);

        /// ------------------ usdc ------------------

        // cfg.usdc = new ERC20Mock("USD Coin", "USDC", 6, cfg.owner);

        /// ------------------ usd+ ------------------

        TransferRestrictor transferRestrictor =
            TransferRestrictor(deployWithCreate2(salt, implBytecodes.transferRestrictorBytecode));

        UsdPlus usdplusImpl = UsdPlus(deployWithCreate2(salt, implBytecodes.usdplusImplBytecode));

        UsdPlus usdplus = UsdPlus(
            deployWithCreate2(
                salt,
                abi.encodePacked(
                    type(ERC1967Proxy).creationCode,
                    abi.encode(
                        address(usdplusImpl),
                        abi.encodeCall(UsdPlus.initialize, (cfg.treasury, transferRestrictor, cfg.owner))
                    )
                )
            )
        );

        WrappedUsdPlus wrappedusdplusImpl =
            WrappedUsdPlus(deployWithCreate2(salt, implBytecodes.wrappedusdplusImplBytecode));

        WrappedUsdPlus wrappedusdplus = WrappedUsdPlus(
            deployWithCreate2(
                salt,
                abi.encodePacked(
                    type(ERC1967Proxy).creationCode,
                    abi.encode(
                        address(wrappedusdplusImpl),
                        abi.encodeCall(WrappedUsdPlus.initialize, (address(usdplus), cfg.owner))
                    )
                )
            )
        );

        /// ------------------ usd+ minter/redeemer ------------------

        UsdPlusMinter minterImpl = UsdPlusMinter(deployWithCreate2(salt, implBytecodes.minterImplBytecode));

        UsdPlusMinter minter = UsdPlusMinter(
            deployWithCreate2(
                salt,
                abi.encodePacked(
                    type(ERC1967Proxy).creationCode,
                    abi.encode(
                        address(minterImpl),
                        abi.encodeCall(UsdPlusMinter.initialize, (address(usdplus), cfg.treasury, cfg.owner))
                    )
                )
            )
        );
        usdplus.setIssuerLimits(address(minter), type(uint256).max, 0);
        minter.setPaymentTokenOracle(cfg.usdc, cfg.paymentTokenOracle);

        UsdPlusRedeemer redeemerImpl = UsdPlusRedeemer(deployWithCreate2(salt, implBytecodes.redeemerImplBytecode));

        UsdPlusRedeemer redeemer = UsdPlusRedeemer(
            deployWithCreate2(
                salt,
                abi.encodePacked(
                    type(ERC1967Proxy).creationCode,
                    abi.encode(
                        address(redeemerImpl), abi.encodeCall(UsdPlusRedeemer.initialize, (address(usdplus), cfg.owner))
                    )
                )
            )
        );
        usdplus.setIssuerLimits(address(redeemer), 0, type(uint256).max);
        redeemer.grantRole(redeemer.FULFILLER_ROLE(), cfg.treasury);
        redeemer.setPaymentTokenOracle(cfg.usdc, cfg.paymentTokenOracle);

        vm.stopBroadcast();
    }

    function deployWithCreate2(bytes32 salt, bytes memory bytecode) internal returns (address addr) {
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        if (addr == address(0)) revert ContractDeploymentFailed();
    }
}
