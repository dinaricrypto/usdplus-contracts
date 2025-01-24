// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ControlledUpgradeable} from "../src/deployment/ControlledUpgradeable.sol";

contract DeployAndUpgradeManager is Script {
    using stdJson for string;

    struct ContractConfig {
        string version;
        ChainConfig[] chainConfigs;
        DeploymentInfo[] deployments;
    }

    struct ChainConfig {
        uint256 chainId;
        InitParams params;
    }

    struct DeploymentInfo {
        string environment;
        ChainDeployment[] chainDeployments;
    }

    struct ChainDeployment {
        uint256 chainId;
        address proxyAddress;
    }

    struct InitParams {
        address treasury;
        address transferRestrictor;
        address usdPlus;
        address router;
        address paymentRecipient;
        address owner;
        address upgrader;
    }

    function run() external {
        string memory contractName = vm.envString("CONTRACT");
        string memory version = vm.envString("VERSION");
        string memory environment = vm.envString("ENVIRONMENT");
        uint256 chainId = block.chainid;

        // Get config path
        string memory configPath = _getConfigPath(contractName, version);

        // Load and deserialize config
        ContractConfig memory config = _deserializeConfig(configPath);

        // Get initialization params for this chain
        InitParams memory params = _getChainParams(config, chainId);
        if (params.owner == address(0)) {
            // If no config found, try to get from env
            params = InitParams({
                treasury: _safeGetEnvAddress("TREASURY_ADDRESS"),
                transferRestrictor: _safeGetEnvAddress("TRANSFER_RESTRICTOR"),
                usdPlus: _safeGetEnvAddress("USDPLUS_ADDRESS"),
                router: _safeGetEnvAddress("ROUTER_ADDRESS"),
                paymentRecipient: _safeGetEnvAddress("PAYMENT_RECIPIENT_ADDRESS"),
                owner: _safeGetEnvAddress("OWNER_ADDRESS"),
                upgrader: _safeGetEnvAddress("UPGRADER_ADDRESS")
            });
            require(params.owner != address(0), "Owner address not set in config or env");
        }

        // Get existing deployment if any
        address proxyAddress = _getDeployedProxy(config, environment, chainId);

        // Deploy implementation
        address implementation = _deployImplementation(contractName);

        uint256 deployerKey = vm.envUint("DEPLOYER_KEY");
        vm.startBroadcast(deployerKey);

        if (proxyAddress == address(0)) {
            // New deployment
            bytes memory initData = _encodeInitData(contractName, params, false);
            proxyAddress = address(new ERC1967Proxy(implementation, initData));
            require(proxyAddress != address(0), "Proxy deployment failed");

            // Update config
            _updateConfig(configPath, config, environment, chainId, proxyAddress);

            console2.log("\nNew deployment:");
        } else {
            // Upgrade
            bytes memory initData = _encodeInitData(contractName, params, true);
            ControlledUpgradeable proxy = ControlledUpgradeable(proxyAddress);
            proxy.upgradeToAndCall(implementation, initData);

            console2.log("\nUpgrade:");
        }

        vm.stopBroadcast();

        console2.log("Contract:", contractName);
        console2.log("Implementation:", implementation);
        console2.log("Proxy:", proxyAddress);
        console2.log("Version:", version);
        console2.log("Chain ID:", chainId);
    }

    function _deserializeConfig(string memory path) internal returns (ContractConfig memory) {
        // Create directory first
        (uint8 major,) = _parseVersion(vm.envString("VERSION"));
        string memory dir = string.concat(vm.projectRoot(), "/releases/v", vm.toString(major));
        vm.createDir(dir, true);

        string memory json;
        try vm.readFile(path) returns (string memory existingJson) {
            if (bytes(existingJson).length > 0) {
                json = existingJson;
            } else {
                json = _createInitialJson();
                vm.writeFile(path, json);
            }
        } catch {
            json = _createInitialJson();
            vm.writeFile(path, json);
        }

        ContractConfig memory config;
        config.version = abi.decode(json.parseRaw(".version"), (string));

        // Parse chain configs
        bytes memory chainsRaw = json.parseRaw(".config");
        if (chainsRaw.length > 0) {
            string[] memory chainIds = abi.decode(chainsRaw, (string[]));
            config.chainConfigs = new ChainConfig[](chainIds.length);

            for (uint256 i = 0; i < chainIds.length; i++) {
                uint256 chainId = vm.parseUint(chainIds[i]);
                bytes memory paramsRaw = json.parseRaw(string.concat(".config.", chainIds[i]));

                InitParams memory params;
                params.treasury = abi.decode(vm.parseJson(string(paramsRaw), ".treasury"), (address));
                params.transferRestrictor =
                    abi.decode(vm.parseJson(string(paramsRaw), ".transferRestrictor"), (address));
                params.usdPlus = abi.decode(vm.parseJson(string(paramsRaw), ".usdPlus"), (address));
                params.router = abi.decode(vm.parseJson(string(paramsRaw), ".router"), (address));
                params.paymentRecipient = abi.decode(vm.parseJson(string(paramsRaw), ".paymentRecipient"), (address));
                params.owner = abi.decode(vm.parseJson(string(paramsRaw), ".owner"), (address));
                params.upgrader = abi.decode(vm.parseJson(string(paramsRaw), ".upgrader"), (address));

                config.chainConfigs[i] = ChainConfig({chainId: chainId, params: params});
            }
        } else {
            // If no chain configs exist, create one for current chain
            config.chainConfigs = new ChainConfig[](1);
            config.chainConfigs[0] = ChainConfig({
                chainId: block.chainid,
                params: InitParams({
                    treasury: _safeGetEnvAddress("TREASURY_ADDRESS"),
                    transferRestrictor: _safeGetEnvAddress("TRANSFER_RESTRICTOR"),
                    usdPlus: _safeGetEnvAddress("USDPLUS_ADDRESS"),
                    router: _safeGetEnvAddress("ROUTER_ADDRESS"),
                    paymentRecipient: _safeGetEnvAddress("PAYMENT_RECIPIENT_ADDRESS"),
                    owner: _safeGetEnvAddress("OWNER_ADDRESS"),
                    upgrader: _safeGetEnvAddress("UPGRADER_ADDRESS")
                })
            });
            // Update the json file with the new config
            json = _addChainConfig(json, block.chainid, config.chainConfigs[0].params);
            vm.writeFile(path, json);
        }

        return config;
    }

    function _safeGetEnvAddress(string memory key) internal view returns (address) {
        try vm.envAddress(key) returns (address value) {
            return value;
        } catch {
            return address(0);
        }
    }

    function _getChainParams(ContractConfig memory config, uint256 chainId) internal pure returns (InitParams memory) {
        for (uint256 i = 0; i < config.chainConfigs.length; i++) {
            if (config.chainConfigs[i].chainId == chainId) {
                return config.chainConfigs[i].params;
            }
        }
        return InitParams(address(0), address(0), address(0), address(0), address(0), address(0), address(0));
    }

    function _getDeployedProxy(ContractConfig memory config, string memory environment, uint256 chainId)
        internal
        pure
        returns (address)
    {
        for (uint256 i = 0; i < config.deployments.length; i++) {
            if (keccak256(bytes(config.deployments[i].environment)) == keccak256(bytes(environment))) {
                for (uint256 j = 0; j < config.deployments[i].chainDeployments.length; j++) {
                    if (config.deployments[i].chainDeployments[j].chainId == chainId) {
                        return config.deployments[i].chainDeployments[j].proxyAddress;
                    }
                }
            }
        }
        return address(0);
    }

    function _updateConfig(
        string memory path,
        ContractConfig memory config,
        string memory environment,
        uint256 chainId,
        address proxyAddress
    ) internal {
        bool found = false;
        // Update existing deployment if found
        for (uint256 i = 0; i < config.deployments.length; i++) {
            if (keccak256(bytes(config.deployments[i].environment)) == keccak256(bytes(environment))) {
                bool chainFound = false;
                for (uint256 j = 0; j < config.deployments[i].chainDeployments.length; j++) {
                    if (config.deployments[i].chainDeployments[j].chainId == chainId) {
                        config.deployments[i].chainDeployments[j].proxyAddress = proxyAddress;
                        chainFound = true;
                        break;
                    }
                }
                if (!chainFound) {
                    // Add new chain deployment
                    uint256 newLength = config.deployments[i].chainDeployments.length + 1;
                    ChainDeployment[] memory newDeployments = new ChainDeployment[](newLength);
                    for (uint256 j = 0; j < config.deployments[i].chainDeployments.length; j++) {
                        newDeployments[j] = config.deployments[i].chainDeployments[j];
                    }
                    newDeployments[newLength - 1] = ChainDeployment({chainId: chainId, proxyAddress: proxyAddress});
                    config.deployments[i].chainDeployments = newDeployments;
                }
                found = true;
                break;
            }
        }

        if (!found) {
            // Add new environment with deployment
            uint256 newLength = config.deployments.length + 1;
            DeploymentInfo[] memory newDeployments = new DeploymentInfo[](newLength);
            for (uint256 i = 0; i < config.deployments.length; i++) {
                newDeployments[i] = config.deployments[i];
            }
            ChainDeployment[] memory chainDeployments = new ChainDeployment[](1);
            chainDeployments[0] = ChainDeployment({chainId: chainId, proxyAddress: proxyAddress});
            newDeployments[newLength - 1] =
                DeploymentInfo({environment: environment, chainDeployments: chainDeployments});
            config.deployments = newDeployments;
        }

        _serializeConfig(path, config);
    }

    function _serializeConfig(string memory path, ContractConfig memory config) internal {
        string memory json = string(
            abi.encodePacked(
                "{",
                '"version":"',
                config.version,
                '",',
                '"config":{',
                _serializeChainConfigs(config.chainConfigs),
                "},",
                '"deployments":{',
                _serializeDeployments(config.deployments),
                "}" "}"
            )
        );
        vm.writeFile(path, json);
    }

    function _serializeChainConfigs(ChainConfig[] memory configs) internal pure returns (string memory) {
        string memory result = "";
        for (uint256 i = 0; i < configs.length; i++) {
            result = string.concat(
                result,
                i > 0 ? "," : "",
                '"',
                vm.toString(configs[i].chainId),
                '":{',
                _serializeInitParams(configs[i].params),
                "}"
            );
        }
        return result;
    }

    function _serializeInitParams(InitParams memory params) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '"treasury":"',
                vm.toString(params.treasury),
                '",',
                '"transferRestrictor":"',
                vm.toString(params.transferRestrictor),
                '",',
                '"usdPlus":"',
                vm.toString(params.usdPlus),
                '",',
                '"router":"',
                vm.toString(params.router),
                '",',
                '"paymentRecipient":"',
                vm.toString(params.paymentRecipient),
                '",',
                '"owner":"',
                vm.toString(params.owner),
                '",',
                '"upgrader":"',
                vm.toString(params.upgrader),
                '"'
            )
        );
    }

    function _serializeDeployments(DeploymentInfo[] memory deployments) internal pure returns (string memory) {
        string memory result = "";
        for (uint256 i = 0; i < deployments.length; i++) {
            result = string.concat(
                result,
                i > 0 ? "," : "",
                '"',
                deployments[i].environment,
                '":{',
                _serializeChainDeployments(deployments[i].chainDeployments),
                "}"
            );
        }
        return result;
    }

    function _serializeChainDeployments(ChainDeployment[] memory deployments) internal pure returns (string memory) {
        string memory result = "";
        for (uint256 i = 0; i < deployments.length; i++) {
            result = string.concat(
                result,
                i > 0 ? "," : "",
                '"',
                vm.toString(deployments[i].chainId),
                '":"',
                vm.toString(deployments[i].proxyAddress),
                '"'
            );
        }
        return result;
    }

    function _encodeInitData(string memory contractName, InitParams memory params, bool isUpgrade)
        internal
        pure
        returns (bytes memory)
    {
        if (isUpgrade) {
            return abi.encodeWithSignature("reinitialize(address)", params.upgrader);
        }

        bytes32 contractHash = keccak256(bytes(contractName));

        if (contractHash == keccak256(bytes("UsdPlus"))) {
            return abi.encodeWithSignature(
                "initialize(address,address,address,address)",
                params.treasury,
                params.transferRestrictor,
                params.owner,
                params.upgrader
            );
        } else if (contractHash == keccak256(bytes("CCIPWaypoint"))) {
            return abi.encodeWithSignature(
                "initialize(address,address,address,address)",
                params.usdPlus,
                params.router,
                params.owner,
                params.upgrader
            );
        } else if (contractHash == keccak256(bytes("UsdPlusMinter"))) {
            return abi.encodeWithSignature(
                "initialize(address,address,address,address)",
                params.usdPlus,
                params.paymentRecipient,
                params.owner,
                params.upgrader
            );
        } else if (contractHash == keccak256(bytes("UsdPlusRedeemer"))) {
            return abi.encodeWithSignature(
                "initialize(address,address,address)", params.usdPlus, params.owner, params.upgrader
            );
        } else if (contractHash == keccak256(bytes("WrappedUsdPlus"))) {
            return abi.encodeWithSignature(
                "initialize(address,address,address)", params.usdPlus, params.owner, params.upgrader
            );
        } else if (contractHash == keccak256(bytes("TransferRestrictor"))) {
            return abi.encodeWithSignature("initialize(address,address)", params.owner, params.upgrader);
        }

        revert("Unsupported contract");
    }

    function _deployImplementation(string memory contractName) internal returns (address) {
        bytes memory bytecode =
            abi.encodePacked(vm.getCode(string.concat("out/", contractName, ".sol/", contractName, ".json")));
        address implementation;
        assembly {
            implementation := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        return implementation;
    }

    function _getConfigPath(string memory contractName, string memory version) internal view returns (string memory) {
        (uint8 major,) = _parseVersion(version);
        return string.concat(
            vm.projectRoot(), "/releases/v", vm.toString(major), "/", _toLowerSnakeCase(contractName), ".json"
        );
    }

    function _parseVersion(string memory version) internal pure returns (uint8 major, uint8 minor) {
        bytes memory versionBytes = bytes(version);
        uint256 pos = 0;

        while (pos < versionBytes.length && versionBytes[pos] != ".") {
            major = major * 10 + uint8(uint8(versionBytes[pos]) - 48);
            pos++;
        }
        pos++;

        while (pos < versionBytes.length && versionBytes[pos] != ".") {
            minor = minor * 10 + uint8(uint8(versionBytes[pos]) - 48);
            pos++;
        }
    }

    function _toLowerSnakeCase(string memory input) internal pure returns (string memory) {
        bytes memory inputBytes = bytes(input);
        bytes memory result = new bytes(inputBytes.length);

        for (uint256 i = 0; i < inputBytes.length; i++) {
            bytes1 char = inputBytes[i];
            result[i] = char >= 0x41 && char <= 0x5A ? bytes1(uint8(char) + 32) : char;
        }
        return string(result);
    }

    function _createInitialJson() internal view returns (string memory) {
        return string.concat(
            '{"version":"', vm.envString("VERSION"), '","config":{},"deployments":{"production":{},"staging":{}}}'
        );
    }

    function _addChainConfig(string memory json, uint256 chainId, InitParams memory params)
        internal
        returns (string memory)
    {
        string memory newJson = vm.serializeString(json, "version", vm.envString("VERSION"));
        newJson =
            vm.serializeAddress(newJson, string.concat(".config.", vm.toString(chainId), ".treasury"), params.treasury);
        newJson = vm.serializeAddress(
            newJson, string.concat(".config.", vm.toString(chainId), ".transferRestrictor"), params.transferRestrictor
        );
        newJson =
            vm.serializeAddress(newJson, string.concat(".config.", vm.toString(chainId), ".usdPlus"), params.usdPlus);
        newJson =
            vm.serializeAddress(newJson, string.concat(".config.", vm.toString(chainId), ".router"), params.router);
        newJson = vm.serializeAddress(
            newJson, string.concat(".config.", vm.toString(chainId), ".paymentRecipient"), params.paymentRecipient
        );
        newJson = vm.serializeAddress(newJson, string.concat(".config.", vm.toString(chainId), ".owner"), params.owner);
        newJson =
            vm.serializeAddress(newJson, string.concat(".config.", vm.toString(chainId), ".upgrader"), params.upgrader);
        return newJson;
    }
}
