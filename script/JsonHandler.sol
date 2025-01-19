// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {stdJson} from "forge-std/StdJson.sol";
import {Vm} from "forge-std/Vm.sol";
import {DeployHelper} from "./DeployHelper.sol";
import {InitializeParams} from "./InitializeParams.sol";

library JsonHandler {
    using stdJson for string;

    error InvalidJsonFormat();
    error SectionNotFound(string section);

    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct NetworkSection {
        string production;
        string staging;
    }

    function _readDeploymentFile(string memory path) internal view returns (string memory) {
        try vm.readFile(path) returns (string memory content) {
            return content;
        } catch {
            return "";
        }
    }

    function _getDefaultTemplate(string memory contractName) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                "{\n",
                '  "name": "',
                contractName,
                '",\n',
                '  "version": "",\n',
                '  "deployments": {\n',
                '      "production": {\n',
                "          ",
                _getEmptyNetworkSection(),
                "\n      },\n",
                '      "staging": {\n',
                "          ",
                _getEmptyNetworkSection(),
                "\n      }\n",
                "  },\n",
                '  "abi": []\n',
                "}"
            )
        );
    }

    function _extractNetworkSections(string memory json) internal pure returns (NetworkSection memory) {
        bytes memory jsonBytes = bytes(json);

        // Initialize with empty sections
        NetworkSection memory sections;
        sections.production = string(abi.encodePacked("{", _getEmptyNetworkSection(), "}"));
        sections.staging = string(abi.encodePacked("{", _getEmptyNetworkSection(), "}"));

        // Extract production section
        uint256 prodStart = _findSectionStart(jsonBytes, "production");
        if (prodStart != type(uint256).max) {
            uint256 prodEnd = _findSectionEnd(jsonBytes, prodStart);
            if (prodEnd != type(uint256).max) {
                sections.production = _extractSection(jsonBytes, prodStart, prodEnd);
            }
        }

        // Extract staging section
        uint256 stagStart = _findSectionStart(jsonBytes, "staging");
        if (stagStart != type(uint256).max) {
            uint256 stagEnd = _findSectionEnd(jsonBytes, stagStart);
            if (stagEnd != type(uint256).max) {
                sections.staging = _extractSection(jsonBytes, stagStart, stagEnd);
            }
        }

        return sections;
    }

    function _updateUsdPlusInitializationParams(
        string memory json,
        string memory version,
        string memory environment,
        // DeployHelper.InitializeParams memory params
        InitializeParams.UsdPlusInitializeParams memory params
    ) internal pure returns (string memory) {
        // Create new initialization section for this version
        string memory newInitSection = string(
            abi.encodePacked(
                '"',
                version,
                '": {',
                '"',
                environment,
                '": {',
                '"initialTreasury":"',
                vm.toString(params.initialTreasury),
                '",',
                '"initialTransferRestrictor":"',
                vm.toString(params.initialTransferRestrictor),
                '",',
                '"initialOwner":"',
                vm.toString(params.initialOwner),
                '",',
                '"upgrader":"',
                vm.toString(params.upgrader),
                '"',
                "}}"
            )
        );

        // Extract existing initialization section
        bytes memory jsonBytes = bytes(json);
        uint256 initStart = _findSectionStart(jsonBytes, "initialization");
        uint256 initEnd = _findSectionEnd(jsonBytes, initStart);

        if (initStart == type(uint256).max || initEnd == type(uint256).max) {
            // No initialization section found, create new one
            // Take everything up to the last } and add initialization section
            uint256 lastBrace = _findLastBrace(jsonBytes);
            bytes memory pre = _sliceBytes(jsonBytes, 0, lastBrace);
            return string(abi.encodePacked(string(pre), ',"initialization":{', newInitSection, "}}"));
        }

        // Add new version to existing initialization section
        bytes memory prefix = _sliceBytes(jsonBytes, 0, initStart);
        bytes memory currentInit = _sliceBytes(jsonBytes, initStart, initEnd);
        bytes memory suffix = _sliceBytes(jsonBytes, initEnd, jsonBytes.length);

        // Check if initialization section is empty
        bool isEmpty = _isEmptyObject(currentInit);

        // If not empty, take the content between the first { and last }
        string memory currentContent = "";
        if (!isEmpty) {
            bytes memory innerContent = _sliceBytes(currentInit, 1, currentInit.length - 1);
            currentContent = string(innerContent);
        }

        string memory separator = isEmpty ? "" : ",";

        return string(
            abi.encodePacked(string(prefix), "{", currentContent, separator, newInitSection, "}", string(suffix))
        );
    }

    function _updateCCIPWayPointIntializationParams(
        string memory json,
        string memory version,
        string memory environment,
        InitializeParams.CCIPWaypointInitializeParams memory params
    ) internal pure returns (string memory) {
        string memory newInitSection = string(
            abi.encodePacked(
                '"',
                version,
                '": {',
                '"',
                environment,
                '": {',
                '"usdPlus":"',
                vm.toString(params.usdPlus),
                '",',
                '"router":"',
                vm.toString(params.router),
                '",',
                '"initialOwner":"',
                vm.toString(params.initialOwner),
                '",',
                '"upgrader":"',
                vm.toString(params.upgrader),
                '"',
                "}}"
            )
        );

        return _updateJsonWithSection(json, newInitSection);
    }

    function _updateUsdPlusMinterInitializationParams(
        string memory json,
        string memory version,
        string memory environment,
        InitializeParams.UsdPlusMinterInitializeParams memory params
    ) internal pure returns (string memory) {
        string memory newInitSection = string(
            abi.encodePacked(
                '"',
                version,
                '": {',
                '"',
                environment,
                '": {',
                '"usdPlus":"',
                vm.toString(params.usdPlus),
                '",',
                '"initialPaymentRecipient":"',
                vm.toString(params.initialPaymentRecipient),
                '",',
                '"initialOwner":"',
                vm.toString(params.initialOwner),
                '",',
                '"upgrader":"',
                vm.toString(params.upgrader),
                '"',
                "}}"
            )
        );

        return _updateJsonWithSection(json, newInitSection);
    }

    function _updateUsdPlusRedeemerInitializationParams(
        string memory json,
        string memory version,
        string memory environment,
        InitializeParams.UsdPlusRedeemerInitializeParams memory params
    ) internal pure returns (string memory) {
        string memory newInitSection = string(
            abi.encodePacked(
                '"',
                version,
                '": {',
                '"',
                environment,
                '": {',
                '"usdPlus":"',
                vm.toString(params.usdPlus),
                '",',
                '"initialOwner":"',
                vm.toString(params.initialOwner),
                '",',
                '"upgrader":"',
                vm.toString(params.upgrader),
                '"',
                "}}"
            )
        );

        return _updateJsonWithSection(json, newInitSection);
    }

    function _updateWrappedUsdPlusInitializationParams(
        string memory json,
        string memory version,
        string memory environment,
        InitializeParams.WrappedUsdPlusInitializeParams memory params
    ) internal pure returns (string memory) {
        string memory newInitSection = string(
            abi.encodePacked(
                '"',
                version,
                '": {',
                '"',
                environment,
                '": {',
                '"usdplus":"',
                vm.toString(params.usdplus),
                '",',
                '"initialOwner":"',
                vm.toString(params.initialOwner),
                '",',
                '"upgrader":"',
                vm.toString(params.upgrader),
                '"',
                "}}"
            )
        );

        return _updateJsonWithSection(json, newInitSection);
    }

    function _updateTransferRestrictorInitializationParams(
        string memory json,
        string memory version,
        string memory environment,
        InitializeParams.TransferRestrictorInitializeParams memory params
    ) internal pure returns (string memory) {
        string memory newInitSection = string(
            abi.encodePacked(
                '"',
                version,
                '": {',
                '"',
                environment,
                '": {',
                '"initialOwner":"',
                vm.toString(params.initialOwner),
                '",',
                '"upgrader":"',
                vm.toString(params.upgrader),
                '"',
                "}}"
            )
        );

        return _updateJsonWithSection(json, newInitSection);
    }

    function _updateJsonWithSection(string memory json, string memory newInitSection)
        internal
        pure
        returns (string memory)
    {
        // Extract existing initialization section
        bytes memory jsonBytes = bytes(json);
        uint256 initStart = _findSectionStart(jsonBytes, "initialization");
        uint256 initEnd = _findSectionEnd(jsonBytes, initStart);

        if (initStart == type(uint256).max || initEnd == type(uint256).max) {
            // No initialization section found, create new one
            uint256 lastBrace = _findLastBrace(jsonBytes);
            bytes memory pre = _sliceBytes(jsonBytes, 0, lastBrace);
            return string(abi.encodePacked(string(pre), ',"initialization":{', newInitSection, "}}"));
        }

        // Add new version to existing initialization section
        bytes memory prefix = _sliceBytes(jsonBytes, 0, initStart);
        bytes memory currentInit = _sliceBytes(jsonBytes, initStart, initEnd);
        bytes memory suffix = _sliceBytes(jsonBytes, initEnd, jsonBytes.length);

        bool isEmpty = _isEmptyObject(currentInit);
        string memory currentContent = "";
        if (!isEmpty) {
            bytes memory innerContent = _sliceBytes(currentInit, 1, currentInit.length - 1);
            currentContent = string(innerContent);
        }

        string memory separator = isEmpty ? "" : ",";

        return string(
            abi.encodePacked(string(prefix), "{", currentContent, separator, newInitSection, "}", string(suffix))
        );
    }

    function _sliceBytes(bytes memory data, uint256 start, uint256 end) internal pure returns (bytes memory) {
        require(end >= start, "Invalid slice");
        require(data.length >= end, "Slice out of bounds");

        bytes memory result = new bytes(end - start);
        for (uint256 i = 0; i < end - start; i++) {
            result[i] = data[start + i];
        }
        return result;
    }

    function _findLastBrace(bytes memory data) internal pure returns (uint256) {
        for (uint256 i = data.length - 1; i > 0; i--) {
            if (data[i] == bytes1("}")) {
                return i;
            }
        }
        revert InvalidJsonFormat();
    }

    function _isEmptyObject(bytes memory data) internal pure returns (bool) {
        // Check if object only contains {} or {whitespace}
        bool foundOpen = false;
        bool foundClose = false;

        for (uint256 i = 0; i < data.length; i++) {
            if (data[i] == bytes1("{")) {
                foundOpen = true;
                continue;
            }
            if (data[i] == bytes1("}")) {
                foundClose = true;
                continue;
            }
            if (data[i] != bytes1(" ") && data[i] != bytes1("\n") && data[i] != bytes1("\t")) {
                return false;
            }
        }

        return foundOpen && foundClose;
    }

    function _buildNetworkSection(uint256 targetChainId, address proxyAddress, string memory currentSection)
        internal
        pure
        returns (string memory)
    {
        string[10] memory chainIds =
            ["1", "11155111", "42161", "421614", "8453", "84532", "81457", "168587773", "7887", "161221135"];

        // Store existing addresses
        string[10] memory existingAddresses;

        // Parse existing addresses
        bytes memory sectionBytes = bytes(currentSection);
        for (uint256 i = 0; i < chainIds.length; i++) {
            (bool found, string memory addr) = _findAddress(sectionBytes, chainIds[i]);
            if (found) {
                existingAddresses[i] = addr;
            }
        }

        // Build new section
        return _buildSectionContent(chainIds, targetChainId, proxyAddress, existingAddresses);
    }

    function _updateJson(
        string memory json,
        string memory contractName,
        string memory version,
        string memory environment,
        string memory networkSection
    ) internal view returns (string memory) {
        NetworkSection memory sections = _extractNetworkSections(json);

        // Update the appropriate section
        if (keccak256(bytes(environment)) == keccak256(bytes("production"))) {
            sections.production = networkSection;
        } else {
            sections.staging = networkSection;
        }

        // Extract initialization section if it exists
        bytes memory jsonBytes = bytes(json);
        uint256 initStart = _findSectionStart(jsonBytes, "initialization");
        uint256 initEnd = _findSectionEnd(jsonBytes, initStart);
        string memory existingInit;

        if (initStart != type(uint256).max && initEnd != type(uint256).max) {
            // Get content without outer braces
            bytes memory initBytes = _sliceBytes(jsonBytes, initStart + 1, initEnd - 1);
            existingInit = string(initBytes);
        }

        // Get addresses from environment variables
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address transferRestrictor = vm.envAddress("TRANSFER_RESTRICTOR");
        address owner = vm.envAddress("OWNER_ADDRESS");
        address upgrader = vm.envAddress("UPGRADER_ADDRESS");

        // Create new initialization content
        string memory newInit = string(
            abi.encodePacked(
                '"',
                version,
                '": {',
                '"',
                environment,
                '": {',
                '"initialTreasury":"',
                vm.toString(treasury),
                '",',
                '"initialTransferRestrictor":"',
                vm.toString(transferRestrictor),
                '",',
                '"initialOwner":"',
                vm.toString(owner),
                '",',
                '"upgrader":"',
                vm.toString(upgrader),
                '"',
                "}}"
            )
        );

        // Combine existing and new initialization
        string memory fullInitSection = string(
            abi.encodePacked("{", bytes(existingInit).length > 0 ? string.concat(existingInit, ",") : "", newInit, "}")
        );

        // Construct updated JSON
        return string(
            abi.encodePacked(
                "{",
                '"name":"',
                contractName,
                '",',
                '"version":"',
                version,
                '",',
                '"deployments":{',
                '"production":',
                sections.production,
                ",",
                '"staging":',
                sections.staging,
                "},",
                '"initialization":',
                fullInitSection,
                ",",
                '"abi":[]',
                "}"
            )
        );
    }

    function _createUsdPlusInitialJson(
        string memory contractName,
        string memory version,
        string memory environment,
        InitializeParams.UsdPlusInitializeParams memory params
    ) internal pure returns (string memory) {
        string memory initSection = string(
            abi.encodePacked(
                "{",
                '"',
                version,
                '": {',
                '"',
                environment,
                '": {',
                '"initialTreasury":"',
                vm.toString(params.initialTreasury),
                '",',
                '"initialTransferRestrictor":"',
                vm.toString(params.initialTransferRestrictor),
                '",',
                '"initialOwner":"',
                vm.toString(params.initialOwner),
                '",',
                '"upgrader":"',
                vm.toString(params.upgrader),
                '"',
                "}}"
            )
        );

        return _createBaseJson(contractName, version, initSection);
    }

    function _createCCIPWaypointInitialJson(
        string memory contractName,
        string memory version,
        string memory environment,
        InitializeParams.CCIPWaypointInitializeParams memory params
    ) internal pure returns (string memory) {
        string memory initSection = string(
            abi.encodePacked(
                "{",
                '"',
                version,
                '": {',
                '"',
                environment,
                '": {',
                '"usdPlus":"',
                vm.toString(params.usdPlus),
                '",',
                '"router":"',
                vm.toString(params.router),
                '",',
                '"initialOwner":"',
                vm.toString(params.initialOwner),
                '",',
                '"upgrader":"',
                vm.toString(params.upgrader),
                '"',
                "}}"
            )
        );

        return _createBaseJson(contractName, version, initSection);
    }

    function _createUsdPlusMinterInitialJson(
        string memory contractName,
        string memory version,
        string memory environment,
        InitializeParams.UsdPlusMinterInitializeParams memory params
    ) internal pure returns (string memory) {
        string memory initSection = string(
            abi.encodePacked(
                "{",
                '"',
                version,
                '": {',
                '"',
                environment,
                '": {',
                '"usdPlus":"',
                vm.toString(params.usdPlus),
                '",',
                '"initialPaymentRecipient":"',
                vm.toString(params.initialPaymentRecipient),
                '",',
                '"initialOwner":"',
                vm.toString(params.initialOwner),
                '",',
                '"upgrader":"',
                vm.toString(params.upgrader),
                '"',
                "}}"
            )
        );

        return _createBaseJson(contractName, version, initSection);
    }

    function _createUsdPlusRedeemerInitialJson(
        string memory contractName,
        string memory version,
        string memory environment,
        InitializeParams.UsdPlusRedeemerInitializeParams memory params
    ) internal pure returns (string memory) {
        string memory initSection = string(
            abi.encodePacked(
                "{",
                '"',
                version,
                '": {',
                '"',
                environment,
                '": {',
                '"usdPlus":"',
                vm.toString(params.usdPlus),
                '",',
                '"initialOwner":"',
                vm.toString(params.initialOwner),
                '",',
                '"upgrader":"',
                vm.toString(params.upgrader),
                '"',
                "}}"
            )
        );

        return _createBaseJson(contractName, version, initSection);
    }

    function _createWrappedUsdPlusInitialJson(
        string memory contractName,
        string memory version,
        string memory environment,
        InitializeParams.WrappedUsdPlusInitializeParams memory params
    ) internal pure returns (string memory) {
        string memory initSection = string(
            abi.encodePacked(
                "{",
                '"',
                version,
                '": {',
                '"',
                environment,
                '": {',
                '"usdplus":"',
                vm.toString(params.usdplus),
                '",',
                '"initialOwner":"',
                vm.toString(params.initialOwner),
                '",',
                '"upgrader":"',
                vm.toString(params.upgrader),
                '"',
                "}}"
            )
        );

        return _createBaseJson(contractName, version, initSection);
    }

    function _createTransferRestrictorInitialJson(
        string memory contractName,
        string memory version,
        string memory environment,
        InitializeParams.TransferRestrictorInitializeParams memory params
    ) internal pure returns (string memory) {
        string memory initSection = string(
            abi.encodePacked(
                "{",
                '"',
                version,
                '": {',
                '"',
                environment,
                '": {',
                '"initialOwner":"',
                vm.toString(params.initialOwner),
                '",',
                '"upgrader":"',
                vm.toString(params.upgrader),
                '"',
                "}}"
            )
        );

        return _createBaseJson(contractName, version, initSection);
    }

    function _createBaseJson(string memory contractName, string memory version, string memory initSection)
        internal
        pure
        returns (string memory)
    {
        return string(
            abi.encodePacked(
                "{",
                '"name":"',
                contractName,
                '",',
                '"version":"',
                version,
                '",',
                '"deployments":{',
                '"production":{',
                _getEmptyNetworkSection(),
                "},",
                '"staging":{',
                _getEmptyNetworkSection(),
                "}",
                "},",
                '"initialization":',
                initSection,
                ",",
                '"abi":[]',
                "}"
            )
        );
    }

    // Internal helper functions
    function _getEmptyNetworkSection() internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '"1":"",',
                '"11155111":"",',
                '"42161":"",',
                '"421614":"",',
                '"8453":"",',
                '"84532":"",',
                '"81457":"",',
                '"168587773":"",',
                '"7887":"",',
                '"161221135":""'
            )
        );
    }

    function _findSectionStart(bytes memory json, string memory section) internal pure returns (uint256) {
        bytes memory pattern = bytes(string.concat('"', section, '": {'));
        uint256 pos = _indexOf(json, pattern);
        if (pos != type(uint256).max) {
            return pos + pattern.length - 1;
        }
        return type(uint256).max;
    }

    function _findSectionEnd(bytes memory json, uint256 start) internal pure returns (uint256) {
        if (start == type(uint256).max) return type(uint256).max;

        uint256 depth = 1;
        for (uint256 i = start + 1; i < json.length; i++) {
            if (json[i] == bytes1("{")) {
                depth++;
            } else if (json[i] == bytes1("}")) {
                depth--;
                if (depth == 0) return i + 1;
            }
        }
        return type(uint256).max;
    }

    function _extractSection(bytes memory json, uint256 start, uint256 end) internal pure returns (string memory) {
        bytes memory sectionContent = new bytes(end - start);
        for (uint256 i = 0; i < end - start; i++) {
            sectionContent[i] = json[start + i];
        }
        return string(sectionContent);
    }

    function _findAddress(bytes memory sectionBytes, string memory chainId)
        internal
        pure
        returns (bool, string memory)
    {
        bytes memory pattern1 = bytes(string.concat('"', chainId, '":"'));
        bytes memory pattern2 = bytes(string.concat('"', chainId, '": "'));

        uint256 start = _indexOf(sectionBytes, pattern1);
        if (start == type(uint256).max) {
            start = _indexOf(sectionBytes, pattern2);
            if (start != type(uint256).max) {
                start += pattern2.length;
            }
        } else {
            start += pattern1.length;
        }

        if (start != type(uint256).max) {
            uint256 end = start;
            while (end < sectionBytes.length && sectionBytes[end] != '"') {
                end++;
            }

            if (end > start) {
                bytes memory addrBytes = new bytes(end - start);
                for (uint256 i = 0; i < end - start; i++) {
                    addrBytes[i] = sectionBytes[start + i];
                }
                return (true, string(addrBytes));
            }
        }
        return (false, "");
    }

    function _buildSectionContent(
        string[10] memory chainIds,
        uint256 targetChainId,
        address proxyAddress,
        string[10] memory existingAddresses
    ) internal pure returns (string memory) {
        string memory section = "{";
        for (uint256 i = 0; i < chainIds.length; i++) {
            uint256 currentChainId;
            bytes memory chainIdBytes = bytes(chainIds[i]);
            for (uint256 j = 0; j < chainIdBytes.length; j++) {
                currentChainId = currentChainId * 10 + (uint8(chainIdBytes[j]) - 48);
            }

            string memory addr;
            if (currentChainId == targetChainId) {
                addr = vm.toString(proxyAddress);
            } else if (bytes(existingAddresses[i]).length > 0) {
                addr = existingAddresses[i];
            } else {
                addr = "";
            }

            section = string.concat(section, '"', chainIds[i], '":"', addr, '"', i < chainIds.length - 1 ? "," : "");
        }
        section = string.concat(section, "}");
        return section;
    }

    function _indexOf(bytes memory haystack, bytes memory needle) internal pure returns (uint256) {
        if (needle.length == 0 || needle.length > haystack.length) {
            return type(uint256).max;
        }

        for (uint256 i = 0; i < haystack.length - needle.length + 1; i++) {
            bool found = true;
            for (uint256 j = 0; j < needle.length; j++) {
                if (haystack[i + j] != needle[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return i;
            }
        }
        return type(uint256).max;
    }
}
