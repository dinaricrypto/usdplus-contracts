import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";

abstract contract ControlledUpgradeable is UUPSUpgradeable, AccessControlDefaultAdminRulesUpgradeable {
    /// ------------------ Types ------------------ ///
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    function version() external pure returns (string memory) {}
}
