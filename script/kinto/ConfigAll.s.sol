// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {TransferRestrictor} from "../../src/TransferRestrictor.sol";
import {UsdPlus} from "../../src/UsdPlus.sol";
import {UsdPlusMinter} from "../../src/UsdPlusMinter.sol";
import {UsdPlusRedeemer} from "../../src/UsdPlusRedeemer.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "../../src/mocks/ERC20Mock.sol";
import {IKintoWallet} from "kinto-contracts-helpers/interfaces/IKintoWallet.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "kinto-contracts-helpers/EntryPointHelper.sol";

contract ConfigAll is Script, EntryPointHelper {
    struct Config {
        TransferRestrictor transferRestrictor;
        UsdPlus usdplus;
        UsdPlusMinter minter;
        UsdPlusRedeemer redeemer;
        address operator;
        address operator2;
        IERC20 usdc;
        AggregatorV3Interface usdcOracle;
    }

    IEntryPoint private _entryPoint;
    address private _sponsorPaymaster;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address owner = vm.envAddress("OWNER");
        string memory environmentName = vm.envString("ENVIRONMENT");
        _entryPoint = IEntryPoint(vm.envAddress("ENTRYPOINT"));
        _sponsorPaymaster = vm.envAddress("SPONSOR_PAYMASTER");

        Config memory cfg = Config({
            transferRestrictor: TransferRestrictor(vm.envAddress("TRANSFER_RESTRICTOR")),
            usdplus: UsdPlus(vm.envAddress("USDPLUS")),
            minter: UsdPlusMinter(vm.envAddress("MINTER")),
            redeemer: UsdPlusRedeemer(vm.envAddress("REDEEMER")),
            operator: vm.envAddress("OPERATOR"),
            operator2: vm.envAddress("OPERATOR2"),
            usdc: IERC20(vm.envAddress("USDC")),
            usdcOracle: AggregatorV3Interface(vm.envAddress("USDC_ORACLE"))
        });

        console.log("deployer: %s", deployer);
        console.log("owner: %s", owner);

        vm.startBroadcast(deployerPrivateKey);

        _grantRoles(cfg, owner, deployerPrivateKey);
        _setIssuerLimits(cfg, owner, deployerPrivateKey);
        if (keccak256(abi.encode(environmentName)) == keccak256(abi.encode("STAGING"))) {
            _grantERC20Roles(cfg, owner, deployerPrivateKey);
        }
        _setOracles(cfg, owner, deployerPrivateKey);

        vm.stopBroadcast();
    }

    function _grantRoles(Config memory cfg, address owner, uint256 deployerPrivateKey) internal {
        // Grant RESTRICTOR_ROLE to operators
        // permissions to call
        // - restrict(address account)
        // - unrestrict(address account)
        _grantRole(
            address(cfg.transferRestrictor),
            cfg.transferRestrictor.RESTRICTOR_ROLE(),
            cfg.operator,
            owner,
            deployerPrivateKey
        );
        _grantRole(
            address(cfg.transferRestrictor),
            cfg.transferRestrictor.RESTRICTOR_ROLE(),
            cfg.operator2,
            owner,
            deployerPrivateKey
        );
        console.log("RESTRICTOR_ROLE granted");

        // Grant OPERATOR_ROLE to operators
        // permissions to call
        // - rebaseAdd(uint128 value)
        // - rebaseMul(uint128 factor)
        _grantRole(address(cfg.usdplus), cfg.usdplus.OPERATOR_ROLE(), cfg.operator, owner, deployerPrivateKey);
        _grantRole(address(cfg.usdplus), cfg.usdplus.OPERATOR_ROLE(), cfg.operator2, owner, deployerPrivateKey);
        console.log("OPERATOR_ROLE granted");

        // Grant PRIVATE_MINTER_ROLE to operators
        // permissions to call
        // - privateMint(IERC20 paymentToken, Permit calldata permit, bytes calldata signature)
        _grantRole(address(cfg.minter), cfg.minter.PRIVATE_MINTER_ROLE(), cfg.operator, owner, deployerPrivateKey);
        _grantRole(address(cfg.minter), cfg.minter.PRIVATE_MINTER_ROLE(), cfg.operator2, owner, deployerPrivateKey);
        console.log("PRIVATE_MINTER_ROLE granted");

        // Grant PRIVATE_REDEEMER_ROLE to operators
        // permissions to call
        // - privateRequestRedeem(IERC20 paymentToken, Permit calldata permit, bytes calldata signature)
        _grantRole(address(cfg.redeemer), cfg.redeemer.PRIVATE_REDEEMER_ROLE(), cfg.operator, owner, deployerPrivateKey);
        _grantRole(
            address(cfg.redeemer), cfg.redeemer.PRIVATE_REDEEMER_ROLE(), cfg.operator2, owner, deployerPrivateKey
        );
        console.log("PRIVATE_REDEEMER_ROLE granted");

        // Grant FULFILLER_ROLE to operators
        // permissions to call
        // - fulfill(uint256 ticket)
        // - cancel(uint256 ticket)
        _grantRole(address(cfg.redeemer), cfg.redeemer.FULFILLER_ROLE(), cfg.operator, owner, deployerPrivateKey);
        _grantRole(address(cfg.redeemer), cfg.redeemer.FULFILLER_ROLE(), cfg.operator2, owner, deployerPrivateKey);
        console.log("FULFILLER_ROLE granted");
    }

    function _setIssuerLimits(Config memory cfg, address owner, uint256 deployerPrivateKey) internal {
        // Set issuer limits for minter and redeemer
        // permissions to call
        // - mint(address to, uint256 value)
        // permissions to call
        // - burn(address from, uint256 value)
        // - burn(uint256 value)
        _setIssuerLimit(cfg.usdplus, address(cfg.minter), type(uint256).max, 0, owner, deployerPrivateKey);
        _setIssuerLimit(cfg.usdplus, address(cfg.redeemer), 0, type(uint256).max, owner, deployerPrivateKey);
    }

    function _setOracles(Config memory cfg, address owner, uint256 deployerPrivateKey) internal {
        _handleOps(
            _entryPoint,
            abi.encodeWithSelector(UsdPlusMinter.setPaymentTokenOracle.selector, cfg.usdc, cfg.usdcOracle),
            owner,
            address(cfg.minter),
            _sponsorPaymaster,
            deployerPrivateKey
        );
        _handleOps(
            _entryPoint,
            abi.encodeWithSelector(UsdPlusRedeemer.setPaymentTokenOracle.selector, cfg.usdc, cfg.usdcOracle),
            owner,
            address(cfg.redeemer),
            _sponsorPaymaster,
            deployerPrivateKey
        );
    }

    function _grantERC20Roles(Config memory cfg, address owner, uint256 deployerPrivateKey) internal {
        // Grant roles for ERC20Mock (USDC)
        ERC20Mock mockUSDC = ERC20Mock(address(cfg.usdc));

        // permissions to call
        // - mint(address to, uint256 value)
        // - burn(address from, uint256 value)
        _grantRole(address(mockUSDC), mockUSDC.MINTER_ROLE(), cfg.operator, owner, deployerPrivateKey);
        _grantRole(address(mockUSDC), mockUSDC.MINTER_ROLE(), cfg.operator2, owner, deployerPrivateKey);
        _grantRole(address(mockUSDC), mockUSDC.BURNER_ROLE(), cfg.operator, owner, deployerPrivateKey);
        _grantRole(address(mockUSDC), mockUSDC.BURNER_ROLE(), cfg.operator2, owner, deployerPrivateKey);
    }

    function _grantRole(
        address contractAddress,
        bytes32 role,
        address account,
        address owner,
        uint256 deployerPrivateKey
    ) internal {
        AccessControl contractAccessControl = AccessControl(contractAddress);
        _handleOps(
            _entryPoint,
            abi.encodeWithSelector(contractAccessControl.grantRole.selector, role, account),
            owner,
            contractAddress,
            _sponsorPaymaster,
            deployerPrivateKey
        );
    }

    function _setIssuerLimit(
        UsdPlus usdplus,
        address account,
        uint256 mintLimit,
        uint256 burnLimit,
        address owner,
        uint256 deployerPrivateKey
    ) internal {
        _handleOps(
            _entryPoint,
            abi.encodeWithSelector(usdplus.setIssuerLimits.selector, account, mintLimit, burnLimit),
            owner,
            address(usdplus),
            _sponsorPaymaster,
            deployerPrivateKey
        );
    }
}
