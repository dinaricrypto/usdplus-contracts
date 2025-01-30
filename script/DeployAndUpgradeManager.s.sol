// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ControlledUpgradeable} from "../src/deployment/ControlledUpgradeable.sol";
import {console2} from "forge-std/console2.sol";

import {VmSafe} from "forge-std/Vm.sol";

contract DeployManager is Script {
    using stdJson for string;

    function run() external {
        // Get params
        address proxyAddress;
        string memory deployedVersion;
        string memory contractName = vm.envString("CONTRACT");
        string memory currentVersion = vm.envString("VERSION");
        string memory environment = vm.envString("ENVIRONMENT");
        string memory configPath =
            string.concat("release_config/", environment, "/", vm.toString(block.chainid), ".json");
        string memory configJson = vm.readFile(configPath);
        bytes memory initParams = configJson.parseRaw(string.concat(".", contractName));

        try vm.envString("DEPLOYED_VERSION") returns (string memory v) {
            deployedVersion = v;
        } catch {
            deployedVersion = "";
        }

        vm.startBroadcast();

        (address previousDeploymentAddress, string memory previousVersion) =
            _getPreviousDeploymentInfo(contractName, deployedVersion, environment, block.chainid);

        if (previousDeploymentAddress == address(0)) {
            proxyAddress = _deployContract(contractName, _getInitData(contractName, initParams, false));
        } else if (
            keccak256(bytes(previousVersion)) != keccak256(bytes(currentVersion)) || bytes(previousVersion).length == 0
        ) {
            proxyAddress =
                _upgradeContract(contractName, previousDeploymentAddress, _getInitData(contractName, initParams, true));
        }

        vm.stopBroadcast();

        // Write result to chain-specific file
        _writeDeployment(environment, block.chainid, contractName, proxyAddress);
    }

    function _getInitData(string memory contractName, bytes memory params, bool isUpgrade)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 nameHash = keccak256(bytes(contractName));

        if (nameHash == keccak256(bytes("UsdPlus"))) {
            return _getInitDataForUsdPlus(params, isUpgrade);
        }
        if (nameHash == keccak256(bytes("TransferRestrictor"))) {
            return _getInitDataForTransferRestrictor(params, isUpgrade);
        }
        if (nameHash == keccak256(bytes("CCIPWaypoint"))) {
            return _getInitDataForCCIPWaypoint(params, isUpgrade);
        }
        if (nameHash == keccak256(bytes("UsdPlusMinter"))) {
            return _getInitDataForUsdPlusMinter(params, isUpgrade);
        }
        if (nameHash == keccak256(bytes("UsdPlusRedeemer"))) {
            return _getInitDataForUsdPlusRedeemer(params, isUpgrade);
        }
        revert(string.concat("Unsupported contract: ", contractName));
    }

    function _getInitDataForUsdPlus(bytes memory params, bool isUpgrade) private pure returns (bytes memory) {
        if (isUpgrade) {
            address upgrader = abi.decode(params, (address));
            return abi.encodeWithSignature("reinitialize(address)", upgrader);
        }

        (address _treasury, address _restrictor, address _owner, address _upgrader) =
            abi.decode(params, (address, address, address, address));
        return abi.encodeWithSignature(
            "initialize(address,address,address,address)", _treasury, _restrictor, _owner, _upgrader
        );
    }

    function _getInitDataForTransferRestrictor(bytes memory params, bool isUpgrade)
        private
        pure
        returns (bytes memory)
    {
        if (isUpgrade) return bytes(""); // No reinitialization needed

        (address owner, address upgrader) = abi.decode(params, (address, address));
        return abi.encodeWithSignature("initialize(address,address)", owner, upgrader);
    }

    function _getInitDataForCCIPWaypoint(bytes memory params, bool isUpgrade) private pure returns (bytes memory) {
        if (isUpgrade) {
            address upgrader = abi.decode(params, (address));
            return abi.encodeWithSignature("reinitialize(address)", upgrader);
        }

        (address _usdPlus, address _router, address _owner, address _upgrader) =
            abi.decode(params, (address, address, address, address));
        return
            abi.encodeWithSignature("initialize(address,address,address,address)", _usdPlus, _router, _owner, _upgrader);
    }

    function _getInitDataForUsdPlusMinter(bytes memory params, bool isUpgrade) private pure returns (bytes memory) {
        if (isUpgrade) {
            address upgrader = abi.decode(params, (address));
            return abi.encodeWithSignature("reinitialize(address)", upgrader);
        }

        (address _usdPlus, address _paymentRecipient, address _owner, address _upgrader) =
            abi.decode(params, (address, address, address, address));
        return abi.encodeWithSignature(
            "initialize(address,address,address,address)", _usdPlus, _paymentRecipient, _owner, _upgrader
        );
    }

    function _getInitDataForUsdPlusRedeemer(bytes memory params, bool isUpgrade) private pure returns (bytes memory) {
        if (isUpgrade) {
            address upgrader = abi.decode(params, (address));
            return abi.encodeWithSignature("reinitialize(address)", upgrader);
        }

        (address _usdPlus, address _owner, address _upgrader) = abi.decode(params, (address, address, address));
        return abi.encodeWithSignature("initialize(address,address,address)", _usdPlus, _owner, _upgrader);
    }

    function _deployContract(string memory contractName, bytes memory initData) internal returns (address) {
        address implementation = _deployImplementation(contractName);
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, initData);
        console2.log("Deployed %s at %s", contractName, address(proxy));
        return address(proxy);
    }

    function _upgradeContract(string memory contractName, address proxyAddress, bytes memory upgradeData)
        internal
        returns (address)
    {
        address implementation = _deployImplementation(contractName);
        if (upgradeData.length > 0) {
            ControlledUpgradeable(payable(proxyAddress)).upgradeToAndCall(implementation, upgradeData);
        } else {
            revert("Upgrade data not provided");
        }
        console2.log("Upgraded %s at %s", contractName, proxyAddress);
        return proxyAddress;
    }

    // Helper functions remain similar to previous implementation
    function _deployImplementation(string memory contractName) internal returns (address) {
        bytes memory creationCode = vm.getCode(string.concat(contractName, ".sol:", contractName));
        require(creationCode.length > 0, string.concat("Contract code not found: ", contractName));

        address implementation;
        assembly {
            implementation := create(0, add(creationCode, 0x20), mload(creationCode))
        }
        require(implementation != address(0), "Implementation deployment failed");
        return implementation;
    }

    function _getPreviousDeploymentInfo(
        string memory contractName,
        string memory deployedVersion,
        string memory environment,
        uint256 chainId
    ) internal returns (address, string memory) {
        if (bytes(deployedVersion).length == 0) return (address(0), "");

        string memory deployedPath = string.concat("releases/", deployedVersion, "/", contractName, ".json");
        if (!vm.exists(deployedPath)) return (address(0), "");

        try vm.parseJsonAddress(
            vm.readFile(deployedPath), string.concat(".deployments.", environment, ".", vm.toString(chainId))
        ) returns (address addr) {
            try vm.parseJsonString(vm.readFile(deployedPath), ".version") returns (string memory version) {
                return (addr, version);
            } catch {
                return (addr, ""); // Address exists, but version retrieval failed
            }
        } catch {
            return (address(0), "");
        }
    }

    function _writeDeployment(
        string memory environment,
        uint256 chainId,
        string memory contractName,
        address deployedAddress
    ) internal {
        // Create temp directory structure
        string memory tempDir = "temp";
        string memory tempEnvDir = string.concat(tempDir, "/", environment);

        if (!vm.exists(tempDir)) {
            vm.createDir(tempDir, true);
        }
        if (!vm.exists(tempEnvDir)) {
            vm.createDir(tempEnvDir, true);
        }

        // Create deployment file under temp/environment/chainId.contractName.json
        string memory deploymentPath =
            string.concat(tempDir, "/", environment, "/", vm.toString(chainId), ".", contractName, ".json");

        string memory json = vm.serializeAddress("{}", "address", deployedAddress);
        vm.writeFile(deploymentPath, json);

        console2.log("Deployment written to:", deploymentPath);
    }
}
