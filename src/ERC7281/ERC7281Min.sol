// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import {IERC7281Min} from "./IERC7281Min.sol";

/// @notice A minimal implementation in the spirit of ERC-7281, generalized to any minter/burner
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/ERC7281/ERC7281Min.sol)
/// @author Modified from defi-wonderland (https://github.com/defi-wonderland/xERC20/blob/main/solidity/contracts/XERC20.sol)
abstract contract ERC7281Min is IERC7281Min {
    // TODO: confirm unlimited minting/burning roles - generalize "lockbox" superminter. more efficient than computing type(uint256).max limits.
    // TODO: confirm unset limits restrict all minting/burning.
    /**
     * @notice The duration it takes for the limits to fully replenish
     */
    uint256 private constant _DURATION = 1 days;

    /// ------------------ Storage ------------------

    struct ERC7281MinStorage {
        mapping(address => IssuerLimits) _issuerLimits;
    }

    // keccak256(abi.encode(uint256(keccak256("dinaricrypto.storage.ERC7281Min")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC7281MIN_STORAGE_LOCATION =
        0x4f7337d0ed9263ce19d7b42b3e4f1fab493f50854a84b6d021b0bdd3f1d6ea00;

    function _getERC7281MinStorage() private pure returns (ERC7281MinStorage storage $) {
        assembly {
            $.slot := ERC7281MIN_STORAGE_LOCATION
        }
    }

    /// ------------------ ERC-7281 ------------------

    function _setIssuerLimits(address issuer, uint256 mintingLimit, uint256 burningLimit) internal {
        _changeMintingLimit(issuer, mintingLimit);
        _changeBurningLimit(issuer, burningLimit);
        emit IssuerLimitsSet(issuer, mintingLimit, burningLimit);
    }

    function mintingMaxLimitOf(address issuer) public view returns (uint256) {
        ERC7281MinStorage storage $ = _getERC7281MinStorage();
        return $._issuerLimits[issuer].mintLimitParams.maxLimit;
    }

    function burningMaxLimitOf(address issuer) public view returns (uint256) {
        ERC7281MinStorage storage $ = _getERC7281MinStorage();
        return $._issuerLimits[issuer].burnLimitParams.maxLimit;
    }

    function mintingCurrentLimitOf(address issuer) public view returns (uint256) {
        ERC7281MinStorage storage $ = _getERC7281MinStorage();
        return _getCurrentLimit($._issuerLimits[issuer].mintLimitParams);
    }

    function burningCurrentLimitOf(address issuer) public view returns (uint256 _limit) {
        ERC7281MinStorage storage $ = _getERC7281MinStorage();
        return _getCurrentLimit($._issuerLimits[issuer].burnLimitParams);
    }

    /**
     * @notice Checks and uses the minting limit of an issuer
     * @param issuer The address of the issuer
     * @param value The change in the limit
     */
    function _useMintingLimits(address issuer, uint256 value) internal {
        uint256 currentLimit = mintingCurrentLimitOf(issuer);
        if (currentLimit < value) revert ERC7281_LimitExceeded();
        ERC7281MinStorage storage $ = _getERC7281MinStorage();
        $._issuerLimits[issuer].mintLimitParams.timestamp = block.timestamp;
        $._issuerLimits[issuer].mintLimitParams.currentLimit = currentLimit - value;
    }

    /**
     * @notice Checks and uses the burning limit of an issuer
     * @param issuer The address of the issuer
     * @param value The change in the limit
     */
    function _useBurningLimits(address issuer, uint256 value) internal {
        uint256 currentLimit = burningCurrentLimitOf(issuer);
        if (currentLimit < value) revert ERC7281_LimitExceeded();
        ERC7281MinStorage storage $ = _getERC7281MinStorage();
        $._issuerLimits[issuer].burnLimitParams.timestamp = block.timestamp;
        $._issuerLimits[issuer].burnLimitParams.currentLimit = currentLimit - value;
    }

    /**
     * @notice Updates the minting limit of an issuer
     * @dev Can only be called by the owner
     * @param issuer The address of the issuer on which we are setting the limit
     * @param newMaxLimit The updated limit we are setting on the issuer
     */
    function _changeMintingLimit(address issuer, uint256 newMaxLimit) internal {
        ERC7281MinStorage storage $ = _getERC7281MinStorage();
        uint256 oldMaxLimit = $._issuerLimits[issuer].mintLimitParams.maxLimit;
        uint256 currentLimit = mintingCurrentLimitOf(issuer);
        $._issuerLimits[issuer].mintLimitParams.maxLimit = newMaxLimit;

        $._issuerLimits[issuer].mintLimitParams.currentLimit =
            _calculateNewCurrentLimit(newMaxLimit, oldMaxLimit, currentLimit);

        $._issuerLimits[issuer].mintLimitParams.ratePerSecond = newMaxLimit / _DURATION;
        $._issuerLimits[issuer].mintLimitParams.timestamp = block.timestamp;
    }

    /**
     * @notice Updates the burning limit of an issuer
     * @dev Can only be called by the owner
     * @param issuer The address of the issuer on which we are setting the limit
     * @param newMaxLimit The updated limit we are setting on the issuer
     */
    function _changeBurningLimit(address issuer, uint256 newMaxLimit) internal {
        ERC7281MinStorage storage $ = _getERC7281MinStorage();
        uint256 oldMaxLimit = $._issuerLimits[issuer].burnLimitParams.maxLimit;
        uint256 currentLimit = burningCurrentLimitOf(issuer);
        $._issuerLimits[issuer].burnLimitParams.maxLimit = newMaxLimit;

        $._issuerLimits[issuer].burnLimitParams.currentLimit =
            _calculateNewCurrentLimit(newMaxLimit, oldMaxLimit, currentLimit);

        $._issuerLimits[issuer].burnLimitParams.ratePerSecond = newMaxLimit / _DURATION;
        $._issuerLimits[issuer].burnLimitParams.timestamp = block.timestamp;
    }

    /**
     * @notice Updates the current limit
     *
     * @param newMaxLimit The new limit
     * @param oldMaxLimit The old limit
     * @param currentLimit The current limit
     */
    function _calculateNewCurrentLimit(uint256 newMaxLimit, uint256 oldMaxLimit, uint256 currentLimit)
        internal
        pure
        returns (uint256 newCurrentLimit)
    {
        uint256 _difference;

        if (oldMaxLimit > newMaxLimit) {
            _difference = oldMaxLimit - newMaxLimit;
            newCurrentLimit = currentLimit > _difference ? currentLimit - _difference : 0;
        } else {
            _difference = newMaxLimit - oldMaxLimit;
            newCurrentLimit = currentLimit + _difference;
        }
    }

    /**
     * @notice Gets the current limit
     */
    function _getCurrentLimit(LimitParameters memory limitParameters) internal view returns (uint256) {
        if (limitParameters.currentLimit == limitParameters.maxLimit) {
            return limitParameters.currentLimit;
        } else if (limitParameters.timestamp + _DURATION <= block.timestamp) {
            return limitParameters.maxLimit;
        } else if (limitParameters.timestamp + _DURATION > block.timestamp) {
            uint256 _timePassed = block.timestamp - limitParameters.timestamp;
            uint256 _calculatedLimit = limitParameters.currentLimit + (_timePassed * limitParameters.ratePerSecond);
            return _calculatedLimit > limitParameters.maxLimit ? limitParameters.maxLimit : _calculatedLimit;
        }
        return limitParameters.currentLimit;
    }
}
