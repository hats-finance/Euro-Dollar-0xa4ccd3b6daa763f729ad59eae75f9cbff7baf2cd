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
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IValidator} from "./interfaces/IValidator.sol";
import {IUSDE} from "./interfaces/IUSDE.sol";
import {IYieldOracle} from "./interfaces/IYieldOracle.sol";

/**
 * @author Rhinefield Technologies Limited
 * @title Eurodollar Invest Token
 */
contract InvestToken is
    Initializable,
    ERC20Upgradeable,
    ERC20PausableUpgradeable,
    ERC20PermitUpgradeable,
    IERC4626,
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

    /// @notice Address of the USDE contract
    IUSDE public immutable usde;

    /// @notice Address of the yield oracle
    IYieldOracle public yieldOracle;

    /* EVENTS */

    event Recovered(address indexed from, address indexed to, uint256 amount);

    /* CONSTRUCTOR */

    /**
     * @dev Constructor that sets the validator and disables initializers.
     * @param _validator Address of the validator contract
     * @param _usde Address of the USDE contract
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(IValidator _validator, IUSDE _usde) {
        validator = _validator;
        usde = _usde;

        _disableInitializers();
    }

    /**
     * @dev Initializes the contract, setting up roles and initial state.
     * @param _initialOwner Address of the initial owner (granted DEFAULT_ADMIN_ROLE)
     */
    function initialize(
        string calldata _name,
        string calldata _symbol,
        address _initialOwner,
        IYieldOracle _yieldOracle
    )
        public
        initializer
    {
        __ERC20_init(_name, _symbol);
        __ERC20Pausable_init();
        __ERC20Permit_init(_name);
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _initialOwner);

        yieldOracle = _yieldOracle;
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
        require(validator.isValidStrict(from, to), "account blocked");

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

    /// ---------- ERC4626 FUNCTIONS ---------- ///
    /**
     * @notice Returns the address of the asset contract.
     */
    function asset() external view returns (address) {
        return address(usde);
    }

    /**
     * @notice Returns the total amount assets (USDE) held in the vault.
     * @return uint256 The total amount of assets held in the vault.
     */
    function totalAssets() external view returns (uint256) {
        return convertToAssets(totalSupply());
    }

    /**
     * @notice Converts the specified amount of assets (USDE) into shares (EUI) using the current price.
     * @param assets  The amount of assets (USDE) to convert into shares (EUI).
     * @return uint256  The equivalent amount of shares (EUI).
     */
    function convertToShares(uint256 assets) public view returns (uint256) {
        return yieldOracle.assetsToShares(assets);
    }

    /**
     * @notice Converts the specified amount of shares (EUI) into assets (USDE) using the current price.
     * @param   shares  The amount of shares (EUI) to convert into assets (USDE).
     * @return  uint256  The equivalent amount of assets (USDE) based on the current exchange rate.
     */
    function convertToAssets(uint256 shares) public view returns (uint256) {
        return yieldOracle.sharesToAssets(shares);
    }

    // Deposit
    /**
     * @notice Returns The maximum amount of assets (USDE) that can be deposited.
     * @return uint256 The maximum amount of assets (USDE) that can be deposited.
     */
    function maxDeposit(address) public view returns (uint256) {
        if (paused()) {
            return 0;
        }
        return type(uint256).max;
    }

    /**
     * @notice Previews the number of shares (EUI) that would be obtained by depositing the specified amount of assets (USDE).
     * @param assets The amount of assets (USDE) to be deposited.
     * @return uint256 The number of shares (EUI) that would be obtained by depositing the specified amount of assets (USDE).
     */
    function previewDeposit(uint256 assets) public view returns (uint256) {
        return convertToShares(assets);
    }

    /**
     * @notice Deposits the specified amount of assets (USDE) to receive the corresponding number of shares (EUI).
     * @param assets The amount of assets (USDE) to be deposited.
     * @param receiver The address that will receive the shares (EUI).
     * @return shares The number of shares (EUI) received.
     */
    function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        shares = convertToShares(assets);
        usde.burn(msg.sender, assets);
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    // Mint
    /**
     * @notice Returns The maximum amount of shares (EUI) that can be minted for a user.
     * @return uint256 The maximum amount of shares (EUI) that can be minted for a user.
     */
    function maxMint(address) public view returns (uint256) {
        if (paused()) {
            return 0;
        }
        return type(uint256).max;
    }

    /**
     * @notice Previews the amount of assets (USDE) that must be deposited to mint the specified number of shares (EUI).
     * @param shares Amount of shares (EUI).
     * @return uint256 The amount of assets (USDE) that must be deposited to mint the specified number of shares (EUI).
     */
    function previewMint(uint256 shares) public view returns (uint256) {
        return convertToAssets(shares);
    }

    /**
     * @notice Deposits the neccesary amount of assets (USDE) to mint the specified amount of assets (EUI) to the receiver's address.
     * @param shares The number of shares (EUI) to mint.
     * @param receiver The address of the receiver who will receive the shares (EUI).
     * @return assets The amount of assets (USDE) minted deposited to mint the specified number of shares (EUI).
     */
    function mint(uint256 shares, address receiver) public returns (uint256 assets) {
        assets = convertToAssets(shares);
        usde.burn(msg.sender, assets);
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    // Withdraw
    /**
     * @notice Returns the maximum amount of assets (USDE) that the specified owner can withdraw based on their share (EUI) balance.
     * @param owner The address of the owner whose maximum withdrawal amount is queried.
     * @return uint256 The maximum amount of assets (USDE) that the owner can withdraw based on their share (EUI) balance.
     */
    function maxWithdraw(address owner) public view returns (uint256) {
        if (paused()) {
            return 0;
        }
        return convertToAssets(this.balanceOf(owner));
    }

    /**
     * @notice Previews the amount of shares (EUI) that will be redeemed when the specified amount of assets (USDE) is withdrawn.
     * @param assets The amount of assets (USDE) to be withdrawn.
     * @return uint256 The preview amount of shares (EUI) that will be redeemed for the given amount of assets (USDE).
     */
    function previewWithdraw(uint256 assets) public view returns (uint256) {
        return convertToShares(assets);
    }

    /**
     * @notice Redeem the necessary amount of shares (EUI) from the vault to receieve specified amount of assets (USDE).
     * @param assets The amount of assets (USDE) to be withdrawn.
     * @param receiver The address that will receive the assets (USDE) upon withdrawal.
     * @param owner The address holding the shares (EUI) to be redeemed.
     * @return shares The amount of shares (EUI) to be withdrawn.
     */
    function withdraw(uint256 assets, address receiver, address owner) public returns (uint256 shares) {
        shares = convertToShares(assets);
        if (owner != msg.sender) _spendAllowance(owner, msg.sender, shares);
        _burn(owner, shares);
        usde.mint(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    // Redeem
    /**
     * @notice Returns the maximum amount of shares (EUI) that can be redeemed for assets (USDE) by the owner of the shares.
     * @param owner The address holding the shares (EUI) to be redeemed.
     * @return uint256 The maximum amount of shares (EUI) that can be redeemed by the owner.
     */
    function maxRedeem(address owner) public view returns (uint256) {
        if (paused()) {
            return 0;
        }
        return this.balanceOf(owner);
    }

    /**
     * @notice Returns the amount of assets (USDE) that would be received by redeeming the specified amount of shares (EUI).
     * @param shares The amount of shares (EUI) to be redeemed for assets (USDE).
     * @return uint256 The amount of assets (USDE) that would be received by redeeming the specified amount of shares (EUI).
     */
    function previewRedeem(uint256 shares) public view returns (uint256) {
        return convertToAssets(shares);
    }

    /**
     * @notice Redeems the specified amount of shares (EUI) for assets (USDE) to the specified receiver.
     * @param shares The amount of shares (EUI) to be redeemed.
     * @param receiver The address that will receive the assets (USDE).
     * @param owner The address of the account that owns the shares (EUI) being redeemed.
     * @return assets The amount of assets (USDE) that have been received.
     */
    function redeem(uint256 shares, address receiver, address owner) public returns (uint256 assets) {
        if (owner != msg.sender) _spendAllowance(owner, msg.sender, shares);
        assets = convertToAssets(shares);
        _burn(owner, shares);
        usde.mint(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    /* ADMIN FUNCTIONS */

    /**
     * @notice Changes the yield oracle. Can only be called by accounts with DEFAULT_ADMIN_ROLE.
     * @param _yieldOracle Address of the new yield oracle
     */
    function changeYieldOracle(IYieldOracle _yieldOracle) public onlyRole(DEFAULT_ADMIN_ROLE) {
        yieldOracle = _yieldOracle;
    }

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

    uint256[49] private __gap;
}
