// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library VersionUtils {
    struct Version {
        uint256 major;
        uint256 minor;
        uint256 patch;
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
