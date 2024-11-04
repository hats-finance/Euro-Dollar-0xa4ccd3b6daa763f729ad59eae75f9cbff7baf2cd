// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: © 2023 Rhinefield Technologies Limited
pragma solidity ^0.8.21;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {IValidator} from "./interfaces/IValidator.sol";

/**
 * @author Rhinefield Technologies Limited
 * @title Eurodollar Stablecoin
 */
contract USDE is
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using SignatureChecker for address;

    /* ROLES */

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINT_ROLE = keccak256("MINT_ROLE");
    bytes32 public constant BURN_ROLE = keccak256("BURN_ROLE");
    bytes32 public constant RESCUER_ROLE = keccak256("RESCUER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /* STATE VARIABLES */

    /// @notice Address of the validator contract
    IValidator public immutable validator;

    /* EVENTS */

    event Recovered(address indexed from, address indexed to, uint256 amount);

    /* CONSTRUCTOR */

    /**
     * @dev Constructor that sets the validator and disables initializers.
     * @param _validator Address of the validator contract
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(IValidator _validator) {
        validator = _validator;
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract, setting up roles and initial state.
     * @param _initialOwner Address of the initial owner (granted DEFAULT_ADMIN_ROLE)
     */
    function initialize(address _initialOwner) public initializer {
        __ERC20_init("EuroDollar", "USDE");
        __ERC20Pausable_init();
        __ERC20Permit_init("EuroDollar");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _initialOwner);
    }

    /* ERC20 FUNCTIONS */

    /**
     * @dev Overrides the _update function to include validation check.
     * @param from Address tokens are transferred from
     * @param to Address tokens are transferred to
     * @param amount Amount of tokens transferred
     */
    function _update(
        address from,
        address to,
        uint256 amount
    )
        internal
        override(ERC20Upgradeable, ERC20PausableUpgradeable)
    {
        require(validator.isValid(from, to), "account blocked");

        super._update(from, to, amount);
    }

    /**
     * @dev Mints new tokens. Can only be called by accounts with MINT_ROLE.
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     * @return bool indicating success
     */
    function mint(address to, uint256 amount) public onlyRole(MINT_ROLE) returns (bool) {
        _mint(to, amount);

        return true;
    }

    /**
     * @dev Burns tokens. Can only be called by accounts with BURN_ROLE.
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     * @return bool indicating success
     */
    function burn(address from, uint256 amount) public onlyRole(BURN_ROLE) returns (bool) {
        _burn(from, amount);

        return true;
    }

    /**
     * @dev Burns tokens with signature verification. Can only be called by accounts with BURN_ROLE.
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     * @param h Hash of the message signed
     * @param signature Signature of the message
     * @return bool indicating success
     */
    function burn(
        address from,
        uint256 amount,
        bytes32 h,
        bytes memory signature
    )
        public
        onlyRole(BURN_ROLE)
        returns (bool)
    {
        require(from.isValidSignatureNow(h, signature), "signature/hash does not match");

        _burn(from, amount);

        return true;
    }

    /**
     * @dev Recovers tokens from one address to another. Can only be called by accounts with RESCUER_ROLE.
     * @param from Address to recover tokens from
     * @param to Address to recover tokens to
     * @param amount Amount of tokens to recover
     * @return bool indicating success
     */
    function recover(address from, address to, uint256 amount) public onlyRole(RESCUER_ROLE) returns (bool) {
        _burn(from, amount);
        _mint(to, amount);

        emit Recovered(from, to, amount);

        return true;
    }

    /* ADMIN FUNCTIONS */

    /**
     * @notice Pauses the contract. Can only be called by accounts with PAUSER_ROLE.
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses the contract. Can only be called by accounts with PAUSER_ROLE.
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function renounceRole(bytes32, address) public pure override {
        revert();
    }

    // ERC1967 Proxy
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    uint256[50] private __gap;
}
