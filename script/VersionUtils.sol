// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library VersionUtils {
    struct Version {
        uint256 major;
        uint256 minor;
        uint256 patch;
    }

    function getDirectoryName(string memory path) internal pure returns (string memory) {
        bytes memory pathBytes = bytes(path);
        uint256 lastSlash = pathBytes.length;

        for (uint256 i = pathBytes.length - 1; i > 0; i--) {
            if (pathBytes[i] == 0x2f) {
                lastSlash = i + 1;
                break;
            }
        }

        bytes memory dirName = new bytes(pathBytes.length - lastSlash);
        for (uint256 i = 0; i < dirName.length; i++) {
            dirName[i] = pathBytes[lastSlash + i];
        }

        return string(dirName);
    }

    function isValidVersion(string memory version) internal pure returns (bool) {
        bytes memory v = bytes(version);
        if (v.length < 5 || v[0] != "v") return false;
        uint256 dotCount = 0;
        for (uint256 i = 1; i < v.length; i++) {
            if (v[i] == ".") dotCount++;
        }
        return dotCount == 2;
    }

    function sortVersionsDescending(string[] memory versions) internal pure returns (string[] memory) {
        string[] memory sorted = versions;
        for (uint256 i = 1; i < sorted.length; i++) {
            string memory key = sorted[i];
            uint256 j = i;
            while (j > 0 && compareVersions(sorted[j - 1], key) < 0) {
                sorted[j] = sorted[j - 1];
                j--;
            }
            sorted[j] = key;
        }
        return sorted;
    }

    function compareVersions(string memory a, string memory b) internal pure returns (int256) {
        Version memory vA = parseVersion(a);
        Version memory vB = parseVersion(b);

        if (vA.major != vB.major) {
            return vA.major > vB.major ? int256(1) : int256(-1);
        }
        if (vA.minor != vB.minor) {
            return vA.minor > vB.minor ? int256(1) : int256(-1);
        }
        if (vA.patch != vB.patch) {
            return vA.patch > vB.patch ? int256(1) : int256(-1);
        }
        return 0;
    }

    function parseVersion(string memory version) internal pure returns (Version memory) {
        bytes memory v = bytes(version);
        uint256[3] memory parts;
        uint256 partIndex = 0;
        uint256 start = 1; // Skip 'v' prefix

        for (uint256 i = start; i < v.length; i++) {
            if (v[i] == ".") {
                parts[partIndex] = parseNumber(v, start, i);
                start = i + 1;
                partIndex++;
                if (partIndex > 2) break;
            }
        }

        // Parse last part
        if (partIndex < 3) {
            parts[partIndex] = parseNumber(v, start, v.length);
        }

        return Version(parts[0], parts[1], parts[2]);
    }

    function parseNumber(bytes memory version, uint256 start, uint256 end) internal pure returns (uint256) {
        uint256 result = 0;
        for (uint256 i = start; i < end; i++) {
            if (version[i] >= "0" && version[i] <= "9") {
                result = result * 10 + (uint256(uint8(version[i])) - 48);
            }
        }
        return result;
    }
}
