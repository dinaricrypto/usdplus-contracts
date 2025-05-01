// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ControlledUpgradeable} from "../src/deployment/ControlledUpgradeable.sol";
import {console2} from "forge-std/console2.sol";
import {VmSafe} from "forge-std/Vm.sol";

interface IVersioned {
    function publicVersion() external view returns (string memory);
}

contract Release is Script {
    using stdJson for string;

    /**
     * @notice Main deployment script for handling new deployments and upgrades
     * @dev Prerequisites:
     *      1. Environment Variables:
     *         - PRIVATE_KEY: (for signing transactions)
     *         - RPC_URL: (for connecting to the network)
     *         - VERSION: Current version being deployed
     *         - ENVIRONMENT: Target environment (e.g., production, staging)
     *         - DEPLOYED_VERSION: (Optional) Previous version for upgrades
     *
     *      2. Required Files:
     *         - release_config/{environment}/{chainId}.json: Contract initialization params
     *
     * @dev Workflow:
     *      1. Loads configuration and parameters from environment and JSON files
     *      2. Checks for previous deployment address
     *      3. If no previous deployment (address(0)):
     *         - Deploys new implementation and proxy
     *      4. If previous deployment exists:
     *         - Checks version difference
     *         - Upgrades if version changed or previous version not available
     *      5. Writes deployment result to artifacts/{environment}/{chainId}.{contractName}.json
     * @dev Run:
     *      ./script/release_sh
     */
    function run() external {
        // Get params
        address proxyAddress;
        string memory deployedVersion;
        string memory contractName = vm.envString("CONTRACT");
        string memory configName = _getConfigName(contractName);
        string memory currentVersion = vm.envString("VERSION");
        string memory environment = vm.envString("ENVIRONMENT");
        string memory configPath =
            string.concat("release_config/", environment, "/", vm.toString(block.chainid), ".json");
        string memory configJson = vm.readFile(configPath);

        // Load deployed version
        try vm.envString("DEPLOYED_VERSION") returns (string memory v) {
            deployedVersion = v;
        } catch {
            deployedVersion = "";
        }

        // Load previous deployment address
        address previousDeploymentAddress =
            _getPreviousDeploymentAddress(configName, deployedVersion, environment, block.chainid);
        if (previousDeploymentAddress != address(0)) {
            console2.log("Previous deployment found at %s", previousDeploymentAddress);
        }

        // Pre-fetch init data for non-beacon contracts
        bytes memory initData = _getInitData(configJson, contractName, false);
        bytes memory upgradeData = _getInitData(configJson, contractName, true);

        vm.startBroadcast();
        if (previousDeploymentAddress == address(0)) {
            console2.log("Deploying contract");
            proxyAddress = _deployContract(contractName, initData);
        } else {
            bool shouldUpgrade = _shouldUpgrade(previousDeploymentAddress, currentVersion);
            if (shouldUpgrade) {
                console2.log("Upgrading contract");
                proxyAddress = _upgradeContract(contractName, previousDeploymentAddress, upgradeData);
            }
        }
        vm.stopBroadcast();

        // Write result using underscore format for file naming
        if (proxyAddress != address(0)) {
            _writeDeployment(environment, block.chainid, contractName, proxyAddress);
        }
    }

    // Mapping of PascalCase contract names to their underscore versions
    function _getConfigName(string memory contractName) internal pure returns (string memory) {
        bytes32 inputHash = keccak256(bytes(contractName));

        if (inputHash == keccak256(bytes("TransferRestrictor"))) return "transfer_restrictor";
        if (inputHash == keccak256(bytes("UsdPlusMinter"))) return "usdplus_minter";
        if (inputHash == keccak256(bytes("CCIPWaypoint"))) return "ccip_waypoint";
        if (inputHash == keccak256(bytes("UsdPlusRedeemer"))) return "usdplus_redeemer";
        if (inputHash == keccak256(bytes("UsdPlus"))) return "usdplus";
        if (inputHash == keccak256(bytes("WrappedUsdPlus"))) return "wrapped_usdplus";

        revert(string.concat("Unknown contract name: ", contractName));
    }

    // Helper to determine if an upgrade is needed
    function _shouldUpgrade(address proxyAddress, string memory currentVersion) internal view returns (bool) {
        string memory previousVersion;
        try IVersioned(proxyAddress).publicVersion() returns (string memory v) {
            previousVersion = v;
        } catch {
            previousVersion = "";
        }
        return
            keccak256(bytes(previousVersion)) != keccak256(bytes(currentVersion)) || bytes(previousVersion).length == 0;
    }

    function _getAddressFromInitData(string memory json, string memory contractName, string memory paramName)
        internal
        pure
        returns (address)
    {
        string memory selector = string.concat(".", contractName, ".", paramName);
        try vm.parseJsonAddress(json, selector) returns (address addr) {
            return addr;
        } catch {
            revert(string.concat("Missing or invalid address at path: ", selector));
        }
    }

    function _getInitData(string memory configJson, string memory contractName, bool isUpgrade)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 nameHash = keccak256(bytes(contractName));

        if (nameHash == keccak256(bytes("UsdPlus"))) {
            return _getInitDataForUsdPlus(configJson, contractName, isUpgrade);
        }
        if (nameHash == keccak256(bytes("TransferRestrictor"))) {
            return _getInitDataForTransferRestrictor(configJson, contractName, isUpgrade);
        }
        if (nameHash == keccak256(bytes("CCIPWaypoint"))) {
            return _getInitDataForCCIPWaypoint(configJson, contractName, isUpgrade);
        }
        if (nameHash == keccak256(bytes("UsdPlusMinter"))) {
            return _getInitDataForUsdPlusMinter(configJson, contractName, isUpgrade);
        }
        if (nameHash == keccak256(bytes("UsdPlusRedeemer"))) {
            return _getInitDataForUsdPlusRedeemer(configJson, contractName, isUpgrade);
        }
        if (nameHash == keccak256(bytes("WrappedUsdPlus"))) {
            return _getInitDataForWrappedUsdPlus(configJson, contractName, isUpgrade);
        }
        revert(string.concat("Unsupported contract: ", contractName));
    }

    function _getInitDataForUsdPlus(string memory configJson, string memory contractName, bool isUpgrade)
        private
        pure
        returns (bytes memory)
    {
        address upgrader = _getAddressFromInitData(configJson, contractName, "upgrader");
        if (isUpgrade) {
            return abi.encodeWithSignature("reinitialize(address)", upgrader);
        }
        address treasury = _getAddressFromInitData(configJson, contractName, "treasury");
        address transferRestrictor = _getAddressFromInitData(configJson, contractName, "transferRestrictor");
        address owner = _getAddressFromInitData(configJson, contractName, "owner");

        return abi.encodeWithSignature(
            "initialize(address,address,address,address)", treasury, transferRestrictor, owner, upgrader
        );
    }

    function _getInitDataForTransferRestrictor(string memory configJson, string memory contractName, bool isUpgrade)
        private
        pure
        returns (bytes memory)
    {
        if (isUpgrade) return bytes("0x");

        address owner = _getAddressFromInitData(configJson, contractName, "owner");
        address upgrader = _getAddressFromInitData(configJson, contractName, "upgrader");

        return abi.encodeWithSignature("initialize(address,address)", owner, upgrader);
    }

    function _getInitDataForCCIPWaypoint(string memory configJson, string memory contractName, bool isUpgrade)
        private
        pure
        returns (bytes memory)
    {
        address upgrader = _getAddressFromInitData(configJson, contractName, "upgrader");
        if (isUpgrade) {
            return abi.encodeWithSignature("reinitialize(address)", upgrader);
        }

        address usdPlus = _getAddressFromInitData(configJson, contractName, "usdPlus");
        address router = _getAddressFromInitData(configJson, contractName, "router");
        address owner = _getAddressFromInitData(configJson, contractName, "owner");

        return abi.encodeWithSignature("initialize(address,address,address,address)", usdPlus, router, owner, upgrader);
    }

    function _getInitDataForUsdPlusMinter(string memory configJson, string memory contractName, bool isUpgrade)
        private
        pure
        returns (bytes memory)
    {
        address upgrader = _getAddressFromInitData(configJson, contractName, "upgrader");
        if (isUpgrade) {
            return abi.encodeWithSignature("reinitialize(address)", upgrader);
        }

        address usdPlus = _getAddressFromInitData(configJson, contractName, "usdPlus");
        address paymentRecipient = _getAddressFromInitData(configJson, contractName, "paymentRecipient");
        address owner = _getAddressFromInitData(configJson, contractName, "owner");
        return abi.encodeWithSignature(
            "initialize(address,address,address,address)", usdPlus, paymentRecipient, owner, upgrader
        );
    }

    function _getInitDataForUsdPlusRedeemer(string memory configJson, string memory contractName, bool isUpgrade)
        private
        pure
        returns (bytes memory)
    {
        address upgrader = _getAddressFromInitData(configJson, contractName, "upgrader");
        if (isUpgrade) {
            return abi.encodeWithSignature("reinitialize(address)", upgrader);
        }

        address usdPlus = _getAddressFromInitData(configJson, contractName, "usdPlus");
        address owner = _getAddressFromInitData(configJson, contractName, "owner");

        return abi.encodeWithSignature("initialize(address,address,address)", usdPlus, owner, upgrader);
    }

    function _getInitDataForWrappedUsdPlus(string memory configJson, string memory contractName, bool isUpgrade)
        private
        pure
        returns (bytes memory)
    {
        address upgrader = _getAddressFromInitData(configJson, contractName, "upgrader");
        address owner = _getAddressFromInitData(configJson, contractName, "owner");
        if (isUpgrade) {
            return abi.encodeWithSignature("reinitialize(address, address)", owner, upgrader);
        }

        address usdPlus = _getAddressFromInitData(configJson, contractName, "usdPlus");

        return abi.encodeWithSignature("initialize(address,address,address)", usdPlus, owner, upgrader);
    }

    function _deployContract(string memory contractName, bytes memory initData) internal returns (address) {
        console2.log("Deploying %s", contractName);
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

    function _getPreviousDeploymentAddress(
        string memory configName,
        string memory deployedVersion,
        string memory environment,
        uint256 chainId
    ) internal view returns (address) {
        if (bytes(deployedVersion).length == 0) return address(0);

        string memory deployedPath = string.concat("releases/v", deployedVersion, "/", configName, ".json");
        if (!vm.exists(deployedPath)) return address(0);

        try vm.parseJsonAddress(
            vm.readFile(deployedPath), string.concat(".deployments.", environment, ".", vm.toString(chainId))
        ) returns (address addr) {
            return addr;
        } catch {
            return address(0);
        }
    }

    function _writeDeployment(
        string memory environment,
        uint256 chainId,
        string memory configName,
        address deployedAddress
    ) internal {
        string memory tempDir = "artifacts";
        string memory tempEnvDir = string.concat(tempDir, "/", environment);

        if (!vm.exists(tempDir)) {
            vm.createDir(tempDir, true);
        }
        if (!vm.exists(tempEnvDir)) {
            vm.createDir(tempEnvDir, true);
        }

        string memory deploymentPath =
            string.concat(tempDir, "/", environment, "/", vm.toString(chainId), ".", configName, ".json");

        string memory json = vm.serializeAddress("{}", "address", deployedAddress);
        vm.writeFile(deploymentPath, json);

        console2.log("Deployment written to:", deploymentPath);
    }
}
