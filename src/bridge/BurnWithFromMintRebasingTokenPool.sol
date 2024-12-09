// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Pool} from "ccip/src/v0.8/ccip/libraries/Pool.sol";
import {BurnWithFromMintTokenPool} from "ccip/src/v0.8/ccip/pools/BurnWithFromMintTokenPool.sol";
import {IBurnMintERC20} from "ccip/src/v0.8/shared/token/ERC20/IBurnMintERC20.sol";

contract BurnWithFromMintRebasingTokenPool is BurnWithFromMintTokenPool {
    error NegativeMintAmount(uint256 amountBurned);

    constructor(
        IBurnMintERC20 token,
        uint8 localTokenDecimals,
        address[] memory allowlist,
        address rmnProxy,
        address router
    ) BurnWithFromMintTokenPool(token, localTokenDecimals, allowlist, rmnProxy, router) {}

    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        external
        virtual
        override
        returns (Pool.ReleaseOrMintOutV1 memory)
    {
        _validateReleaseOrMint(releaseOrMintIn);
        uint256 balancePre = IBurnMintERC20(address(i_token)).balanceOf(releaseOrMintIn.receiver);

        // Mint to the receiver
        IBurnMintERC20(address(i_token)).mint(releaseOrMintIn.receiver, releaseOrMintIn.amount);

        uint256 balancePost = IBurnMintERC20(address(i_token)).balanceOf(releaseOrMintIn.receiver);

        // Mint should not reduce the number of tokens in the receiver
        if (balancePost < balancePre) {
            revert NegativeMintAmount(balancePre - balancePost);
        }

        emit Minted(msg.sender, releaseOrMintIn.receiver, balancePost - balancePre);
        return Pool.ReleaseOrMintOutV1({destinationAmount: balancePost - balancePre});
    }

    function typeAndVersion() external pure override returns (string memory) {
        return "BurnWithFromMintRebasingTokenPool 1.5.0";
    }
}
