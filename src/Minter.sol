// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {UsdPlus} from "./USD+.sol";

/// @notice stablecoin minter
/// @author Dinari (https://github.com/dinaricrypto/usdplus-contracts/blob/main/src/Minter.sol)
contract Minter is Ownable {
    using SafeERC20 for IERC20;

    event TreasurySet(address indexed treasury);
    event PaymentOracleSet(IERC20 indexed payment, AggregatorV3Interface oracle);
    event Issued(address indexed to, IERC20 indexed payment, uint256 paymentAmount, uint256 issueAmount);

    error ZeroAddress();
    error PaymentNotAccepted();

    /// @notice USD+
    UsdPlus public immutable usdplus;

    /// @notice treasury for payment tokens
    address public treasury;

    /// @notice is this payment token accepted?
    mapping(IERC20 => AggregatorV3Interface) public paymentOracle;

    constructor(UsdPlus _usdplus, address initialOwner) Ownable(initialOwner) {
        usdplus = _usdplus;
    }

    // ------------------ Admin ------------------

    /// @notice set treasury
    /// @param _treasury treasury
    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit TreasurySet(_treasury);
    }

    /// @notice set payment token oracle
    /// @param payment payment token
    /// @param oracle oracle
    function setPaymentOracle(IERC20 payment, AggregatorV3Interface oracle) external onlyOwner {
        paymentOracle[payment] = oracle;
        emit PaymentOracleSet(payment, oracle);
    }

    // ------------------ Mint ------------------

    /// @notice calculate USD+ amount to mint for payment
    /// @param payment payment token
    /// @param amount amount of payment token
    function issueAmount(IERC20 payment, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface oracle = paymentOracle[payment];
        if (address(oracle) == address(0)) revert PaymentNotAccepted();

        (, int256 price,,,) = oracle.latestRoundData();
        return amount * uint256(price);
    }

    /// @notice mint USD+ for payment
    /// @param to recipient
    /// @param payment payment token
    /// @param amount amount of USD+ to mint
    function issue(address to, IERC20 payment, uint256 amount) external {
        if (to == address(0)) revert ZeroAddress();

        uint256 _issueAmount = issueAmount(payment, amount);
        emit Issued(to, payment, amount, _issueAmount);

        payment.safeTransferFrom(msg.sender, treasury, amount);
        usdplus.mint(to, _issueAmount);
    }
}
