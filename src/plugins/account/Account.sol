// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {C} from "src/libraries/C.sol";
import {Asset} from "src/libraries/LibUtils.sol";
import {IAccount} from "src/interfaces/IAccount.sol";

abstract contract Account is IAccount, AccessControl, ReentrancyGuard {
    event LoadedFromUser(Asset asset, uint256 amount, bytes parameters);
    event LoadedFromPosition(Asset asset, uint256 amount, bytes parameters);
    event UnloadedToUser(Asset asset, uint256 amount, bytes parameters);
    event UnloadedToPosition(address position, Asset asset, uint256 amount, bool isLockedColl, bytes parameters);
    event LockedCollateral(Asset asset, uint256 amount, bytes parameters);
    event UnlockedCollateral(Asset asset, uint256 amount, bytes parameters);

    constructor(address bookkeeperAddr) {
        _setupRole(C.BOOKKEEPER_ROLE, bookkeeperAddr);
    }

    function loadFromUser(
        Asset calldata asset,
        uint256 amount,
        bytes calldata parameters
    ) external payable override nonReentrant {
        _loadFromUser(asset, amount, parameters);
        emit LoadedFromUser(asset, amount, parameters);
    }

    function loadFromPosition(
        Asset calldata asset,
        uint256 amount,
        bytes calldata parameters
    ) external payable override nonReentrant {
        _loadFromPosition(asset, amount, parameters);
        emit LoadedFromPosition(asset, amount, parameters);
    }

    function unloadToUser(
        Asset calldata asset,
        uint256 amount,
        bytes calldata parameters
    ) external override nonReentrant {
        _unloadToUser(asset, amount, parameters);
        emit UnloadedToUser(asset, amount, parameters);
    }

    function unloadToPosition(
        address position,
        Asset calldata asset,
        uint256 amount,
        bool isLockedColl,
        bytes calldata parameters
    ) external override onlyRole(C.BOOKKEEPER_ROLE) {
        _unloadToPosition(position, asset, amount, isLockedColl, parameters);
        emit UnloadedToPosition(position, asset, amount, isLockedColl, parameters);
    }

    function lockCollateral(
        Asset calldata asset,
        uint256 amount,
        bytes calldata parameters
    ) external override onlyRole(C.BOOKKEEPER_ROLE) {
        _lockCollateral(asset, amount, parameters);
        emit LockedCollateral(asset, amount, parameters);
    }

    function unlockCollateral(
        Asset calldata asset,
        uint256 amount,
        bytes calldata parameters
    ) external override onlyRole(C.BOOKKEEPER_ROLE) {
        _unlockCollateral(asset, amount, parameters);
        emit UnlockedCollateral(asset, amount, parameters);
    }

    function _loadFromUser(Asset calldata asset, uint256 amount, bytes calldata parameters) internal virtual;

    function _loadFromPosition(Asset calldata asset, uint256 amount, bytes calldata parameters) internal virtual;

    function _unloadToUser(Asset calldata asset, uint256 amount, bytes calldata parameters) internal virtual;

    function _unloadToPosition(
        address position,
        Asset calldata asset,
        uint256 amount,
        bool isLockedColl,
        bytes calldata parameters
    ) internal virtual;

    function _lockCollateral(Asset calldata asset, uint256 amount, bytes calldata parameters) internal virtual;

    function _unlockCollateral(Asset calldata asset, uint256 amount, bytes calldata parameters) internal virtual;
}
