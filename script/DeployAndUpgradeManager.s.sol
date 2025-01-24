// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ControlledUpgradeable} from "../src/deployment/ControlledUpgradeable.sol";
import {console} from "forge-std/console.sol";

contract DeployManager is Script {
    using stdJson for string;

    struct DeploymentConfig {
        string version;
        mapping(string => mapping(uint256 => address)) deployments; // environment -> chainId -> address
    }

    function run() external {
        string memory contractName = vm.envString("CONTRACT");
        string memory version = vm.envString("VERSION");
        string memory environment = vm.envString("ENVIRONMENT");
        uint256 chainId = block.chainid;

        require(bytes(contractName).length > 0, "CONTRACT_NAME not set");
        require(bytes(version).length > 0, "VERSION not set");
        require(bytes(environment).length > 0, "ENVIRONMENT not set");

        // Load chain-specific config
        string memory configPath = string.concat("releases/config/", vm.toString(chainId), ".json");
        string memory configJson = vm.readFile(configPath);
        bytes memory initParams = configJson.parseRaw(string.concat(".", contractName));

        // Check existing deployment
        address existingAddr = _getExistingDeployment(contractName, version, environment, chainId);
        address proxyAddress;

        vm.startBroadcast();
        if (existingAddr != address(0)) {
            bytes memory upgradeData = _getInitData(contractName, initParams, true);
            proxyAddress = _upgradeContract(contractName, existingAddr, upgradeData);
        } else {
            bytes memory initData = _getInitData(contractName, initParams, false);
            proxyAddress = _deployNewContract(contractName, initData);
        }
        vm.stopBroadcast();

        _recordDeployment(contractName, version, environment, chainId, proxyAddress);
    }

    function _getInitData(string memory contractName, bytes memory params, bool isUpgrade)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 nameHash = keccak256(bytes(contractName));

        if (nameHash == keccak256(bytes("UsdPlus"))) {
            return _handleUsdPlus(params, isUpgrade);
        }
        if (nameHash == keccak256(bytes("TransferRestrictor"))) {
            return _handleTransferRestrictor(params, isUpgrade);
        }
        if (nameHash == keccak256(bytes("CCIPWaypoint"))) {
            return _handleCCIPWaypoint(params, isUpgrade);
        }
        if (nameHash == keccak256(bytes("UsdPlusMinter"))) {
            return _handleUsdPlusMinter(params, isUpgrade);
        }
        if (nameHash == keccak256(bytes("UsdPlusRedeemer"))) {
            return _handleUsdPlusRedeemer(params, isUpgrade);
        }
        revert(string.concat("Unsupported contract: ", contractName));
    }

    function _handleUsdPlus(bytes memory params, bool isUpgrade) private pure returns (bytes memory) {
        if (isUpgrade) {
            address upgrader = abi.decode(params, (address));
            return abi.encodeWithSignature("reinitialize(address)", upgrader);
        }

        (address treasury, address restrictor, address owner, address upgrader) =
            abi.decode(params, (address, address, address, address));
        return abi.encodeWithSignature(
            "initialize(address,address,address,address)", treasury, restrictor, owner, upgrader
        );
    }

    function _handleTransferRestrictor(bytes memory params, bool isUpgrade) private pure returns (bytes memory) {
        if (isUpgrade) return bytes(""); // No reinitialization needed

        (address owner, address upgrader) = abi.decode(params, (address, address));
        return abi.encodeWithSignature("initialize(address,address)", owner, upgrader);
    }

    function _handleCCIPWaypoint(bytes memory params, bool isUpgrade) private pure returns (bytes memory) {
        if (isUpgrade) {
            address upgrader = abi.decode(params, (address));
            return abi.encodeWithSignature("reinitialize(address)", upgrader);
        }

        (address usdPlus, address router, address owner, address upgrader) =
            abi.decode(params, (address, address, address, address));
        return abi.encodeWithSignature("initialize(address,address,address,address)", usdPlus, router, owner, upgrader);
    }

    function _handleUsdPlusMinter(bytes memory params, bool isUpgrade) private pure returns (bytes memory) {
        if (isUpgrade) {
            address upgrader = abi.decode(params, (address));
            return abi.encodeWithSignature("reinitialize(address)", upgrader);
        }

        (address usdPlus, address paymentRecipient, address owner, address upgrader) =
            abi.decode(params, (address, address, address, address));
        return abi.encodeWithSignature(
            "initialize(address,address,address,address)", usdPlus, paymentRecipient, owner, upgrader
        );
    }

    function _handleUsdPlusRedeemer(bytes memory params, bool isUpgrade) private pure returns (bytes memory) {
        if (isUpgrade) {
            address upgrader = abi.decode(params, (address));
            return abi.encodeWithSignature("reinitialize(address)", upgrader);
        }

        (address usdPlus, address owner, address upgrader) = abi.decode(params, (address, address, address));
        return abi.encodeWithSignature("initialize(address,address,address)", usdPlus, owner, upgrader);
    }

    function _deployNewContract(string memory contractName, bytes memory initData) internal returns (address) {
        address implementation = _deployImplementation(contractName);
        ERC1967Proxy proxy = new ERC1967Proxy(implementation, initData);
        console.log("Deployed %s at %s", contractName, address(proxy));
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
            revert ("Upgrade data not provided");
        }
        console.log("Upgraded %s at %s", contractName, proxyAddress);
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

    function _getExistingDeployment(
        string memory contractName,
        string memory currentVersion,
        string memory environment,
        uint256 chainId
    ) internal returns (address) {
        string memory prevVersion = _getPreviousVersion(currentVersion);
        if (bytes(prevVersion).length == 0) return address(0);

        string memory prevDeploymentPath = string.concat("releases/", prevVersion, "/", contractName, ".json");
        if (!vm.exists(prevDeploymentPath)) return address(0);

        string memory prevJson = vm.readFile(prevDeploymentPath);
        return prevJson.readAddress(string.concat(".deployments.", environment, ".", vm.toString(chainId)));
    }

    function _recordDeployment(
        string memory contractName,
        string memory version,
        string memory environment,
        uint256 chainId,
        address deployedAddress
    ) internal {
        string memory releaseDir = string.concat("releases/", version, "/");
        vm.createDir(releaseDir, true);

        string memory deploymentPath = string.concat(releaseDir, contractName, ".json");
        string memory json = vm.exists(deploymentPath) ? vm.readFile(deploymentPath) : "{}";

        json = vm.serializeAddress(
            json, string.concat(".deployments.", environment, ".", vm.toString(chainId)), deployedAddress
        );
        json = vm.serializeString(json, ".version", version);
        vm.writeJson(json, deploymentPath);
    }

    function _getPreviousVersion(string memory currentVersion) internal pure returns (string memory) {
        bytes memory versionBytes = bytes(currentVersion);
        uint256 length = versionBytes.length;

        // Basic format validation
        if (length < 5 || versionBytes[0] != "v") return "";
        if (versionBytes[1] == "." || versionBytes[length - 1] == ".") return "";

        // Find dot positions
        uint8[2] memory dotPositions;
        uint8 dotCount = 0;
        for (uint256 i = 1; i < length; i++) {
            if (versionBytes[i] == ".") {
                if (dotCount >= 2) return "";
                dotPositions[dotCount] = uint8(i);
                dotCount++;
            }
        }
        if (dotCount != 2) return "";

        // Extract version components
        uint256 major = _parseVersionComponent(versionBytes, 1, dotPositions[0]);
        uint256 minor = _parseVersionComponent(versionBytes, dotPositions[0] + 1, dotPositions[1]);
        uint256 patch = _parseVersionComponent(versionBytes, dotPositions[1] + 1, length);

        // Decrement logic
        if (patch > 0) {
            patch--;
        } else {
            if (minor > 0) {
                minor--;
                patch = 9; // Assuming max patch version 9 per your example
            } else {
                if (major > 0) {
                    major--;
                    minor = 9;
                    patch = 9;
                } else {
                    return ""; // Can't decrement below v0.0.0
                }
            }
        }

        // Reconstruct previous version
        return string(abi.encodePacked("v", _uintToString(major), ".", _uintToString(minor), ".", _uintToString(patch)));
    }

    // Helper function to parse version components
    function _parseVersionComponent(bytes memory version, uint256 start, uint256 end) private pure returns (uint256) {
        uint256 result = 0;
        for (uint256 i = start; i < end; i++) {
            if (version[i] < "0" || version[i] > "9") return 0;
            result = result * 10 + (uint256(uint8(version[i])) - 48);
        }
        return result;
    }

    // Helper function to convert uint to string
    function _uintToString(uint256 value) private pure returns (string memory) {
        if (value == 0) return "0";

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }
        return string(buffer);
    }
}
