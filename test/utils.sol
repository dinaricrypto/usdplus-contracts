// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

contract TestUtils {
    function OzAccessControlRevert() public pure returns (string memory) {
        return
        "AccessControlUnauthorizedAccount(0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496, 0x0000000000000000000000000000000000000000000000000000000000000000)"
        "AccessControl: account is missing role";
    }
}
