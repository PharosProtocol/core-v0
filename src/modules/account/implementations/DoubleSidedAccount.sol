// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/LibUtil.sol";
import {C} from "src/C.sol";

import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IAccount} from "src/modules/account/IAccount.sol";

/**
 * Account for holding ETH and ERC20 assets, to use for either lending or borrowing through an Agreement.
 * ~ Not compatible with other asset types ~
 */
contract DoubleSidedAccount is AccessControl, IAccount {
    struct Parameters {
        address owner;
        // An owner-unique id for this account.
        bytes32 salt;
    }

    event AssetLoaded(Asset indexed asset, uint256 amount, bytes indexed parameters);
    event AssetUnloaded(Asset indexed asset, uint256 amount, bytes indexed parameters);
    event PositionCapitalized(address indexed position, Asset indexed asset, uint256 amount, bytes indexed parameters);

    mapping(bytes32 => mapping(bytes32 => uint256)) private accounts; // account id => asset hash => amount

    constructor(address bookkeeperAddr) {
        _grantRole(C.BOOKKEEPER_ROLE, bookkeeperAddr);
    }

    function load(Asset calldata asset, uint256 amount, bytes calldata parameters) external payable override {
        _load(msg.sender, asset, amount, parameters);
    }

    /// @dev the bookkeeper is the only actor that is allowed to act as a delegate. Else approved funds are at risk.
    function sideLoad(address from, Asset calldata asset, uint256 amount, bytes calldata parameters)
        external
        payable
        override
        onlyRole(C.BOOKKEEPER_ROLE)
    {
        _load(from, asset, amount, parameters);
    }

    function _load(address from, Asset calldata asset, uint256 amount, bytes calldata parameters) private {
        Parameters memory params = abi.decode(parameters, (Parameters));

        bytes32 accountId = _getId(params.owner, params.salt);

        accounts[accountId][keccak256(abi.encode(asset))] += amount;
        Utils.receiveAsset(from, asset, amount); // ETH and ERC20 implemented

        emit AssetLoaded(asset, amount, parameters);
    }

    function unload(Asset calldata asset, uint256 amount, bytes calldata parameters) external override {
        Parameters memory params = abi.decode(parameters, (Parameters));

        require(msg.sender == params.owner, "unload: not owner");
        bytes32 accountId = _getId(params.owner, params.salt);

        accounts[accountId][keccak256(abi.encode(asset))] -= amount; // verifies account balance is sufficient
        Utils.sendAsset(msg.sender, asset, amount); // ETH and ERC20 implemented

        emit AssetUnloaded(asset, amount, parameters);
    }

    // NOTE could bypass need hre (and other modules) for C.BOOKKEEPER_ROLE by verifying signed agreement and tracking
    //      which have already been processed.
    function capitalize(address position, Asset calldata asset, uint256 amount, bytes calldata parameters)
        external
        override
        onlyRole(C.BOOKKEEPER_ROLE)
    {
        Parameters memory params = abi.decode(parameters, (Parameters));

        bytes32 id = _getId(params.owner, params.salt);
        accounts[id][keccak256(abi.encode(asset))] -= amount;
        Utils.sendAsset(position, asset, amount);

        emit PositionCapitalized(position, asset, amount, parameters);
    }

    function getOwner(bytes calldata parameters) external pure override returns (address) {
        return abi.decode(parameters, (Parameters)).owner;
    }

    function getBalance(Asset calldata asset, bytes calldata parameters)
        external
        view
        override
        returns (uint256 amounts)
    {
        Parameters memory params = abi.decode(parameters, (Parameters));
        bytes32 accountId = _getId(params.owner, params.salt);
        return accounts[accountId][keccak256(abi.encode(asset))];
    }

    function _getId(address owner, bytes32 salt) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, salt));
    }
}
