// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TransferRestrictor} from "../src/TransferRestrictor.sol";
import {
    IAccessControlDefaultAdminRules,
    IAccessControl
} from "openzeppelin-contracts/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import {UsdPlusMinter} from "../src/UsdPlusMinter.sol";
import {UsdPlus} from "../src/UsdPlus.sol";
import {ERC20Mock} from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import "../src/UsdPlusPrivateMinter.sol";


contract UsdPlusPrivateMinterTest is Test {
    event Issued(
        address indexed receiver, IERC20 indexed paymentToken, uint256 paymentTokenAmount, uint256 usdPlusAmount
    );

    event VaultSet(address indexed vault);
    event PaymentTokenSet(address indexed paymentToken);

    UsdPlus usdplus;
    UsdPlusMinter minter;
    UsdPlusPrivateMinter privateMinter;
    TransferRestrictor transferRestrictor;
    ERC20Mock paymentToken;

    address public constant ADMIN = address(0x1234);
    address public constant TREASURY = address(0x1235);
    address public constant USER = address(0x1238);
    address constant usdcPriceOracle = 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3;

    function setUp() public {
        transferRestrictor = new TransferRestrictor(ADMIN);
        UsdPlus usdplusImpl = new UsdPlus();
        usdplus = UsdPlus(
            address(
                new ERC1967Proxy(
                    address(usdplusImpl), abi.encodeCall(UsdPlus.initialize, (TREASURY, transferRestrictor, ADMIN))
                )
            )
        );
        UsdPlusMinter minterImpl = new UsdPlusMinter();
        minter = UsdPlusMinter(
            address(
                new ERC1967Proxy(
                    address(minterImpl), abi.encodeCall(UsdPlusMinter.initialize, (address(usdplus), TREASURY, ADMIN))
                )
            )
        );
        UsdPlusPrivateMinter privateMinterImpl = new UsdPlusPrivateMinter();
        paymentToken = new ERC20Mock();
        privateMinter = UsdPlusPrivateMinter(
            address(
                new ERC1967Proxy(
                    address(privateMinterImpl), abi.encodeCall(UsdPlusPrivateMinter.initialize, (address(usdplus), address(paymentToken), ADMIN))
                )
            )
        );

    }


    function testSetVault() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), privateMinter.DEFAULT_ADMIN_ROLE()
            )
        );
        privateMinter.setVault(TREASURY);

    }
}