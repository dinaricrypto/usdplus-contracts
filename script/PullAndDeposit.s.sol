// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import {ERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {UsdPlusMinter} from "../src/UsdPlusMinter.sol";

contract PullAndDeposit is Script {
    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    function getPermitStructHash(Permit memory _permit) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(PERMIT_TYPEHASH, _permit.owner, _permit.spender, _permit.value, _permit.nonce, _permit.deadline)
        );
    }

    function getPermitTypedDataHash(bytes32 domainSeparator, Permit memory _permit) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, getPermitStructHash(_permit)));
    }

    function run() external {
        uint256 userPrivateKey = vm.envUint("USER_KEY");
        uint256 operatorPrivateKey = vm.envUint("OPERATOR_KEY");
        ERC20Permit usdc = ERC20Permit(vm.envAddress("USDC"));
        UsdPlus usdplus = UsdPlus(vm.envAddress("USDPLUS"));
        UsdPlusMinter minter = UsdPlusMinter(vm.envAddress("USDPLUS_MINTER"));

        uint256 amount = 10_000_000; // 10 USDC
        address user = vm.addr(userPrivateKey);
        address operator = vm.addr(operatorPrivateKey);

        console.log("user: %s", user);
        console.log("operator: %s", operator);
        console.log("USDC amount: %d", amount);

        // User sign USDC permit
        vm.startBroadcast(userPrivateKey);

        Permit memory permit = Permit({
            owner: user,
            spender: operator,
            value: amount,
            nonce: usdc.nonces(user),
            deadline: block.timestamp + 30 minutes
        });

        bytes32 digest = getPermitTypedDataHash(usdc.DOMAIN_SEPARATOR(), permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

        vm.stopBroadcast();

        // Operator pull USDC and deposit USDC to USD+
        vm.startBroadcast(operatorPrivateKey);

        // Pull from user
        usdc.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
        usdc.transferFrom(permit.owner, operator, permit.value);

        // Deposit to USD+
        usdc.approve(address(minter), permit.value);
        uint256 usdplusAmount = minter.deposit(usdc, permit.value, operator);
        console.log("USD+ amount: %d", usdplusAmount);

        // Transfer USD+ to user
        usdplus.transfer(user, usdplusAmount);

        vm.stopBroadcast();
    }
}
