// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {C} from "src/libraries/C.sol";
import {IAccount} from "src/interfaces/IAccount.sol";

abstract contract Account is IAccount, AccessControl, ReentrancyGuard {
    event LoadedFromUser(bytes assetData, uint256 amount, bytes parameters);
    event LoadedFromPosition(bytes assetData, uint256 amount, bytes parameters);
    event UnloadedToUser(bytes assetData, uint256 amount, bytes parameters);
    event UnloadedToPosition(address position, bytes assetData, uint256 amount, bytes parameters);

    constructor(address bookkeeperAddr) {
        _setupRole(C.BOOKKEEPER_ROLE, bookkeeperAddr);
    }

    function loadFromUser(
        bytes calldata assetData,
        uint256 amount,
        bytes calldata parameters
    ) external payable override nonReentrant {
        _loadFromUser(assetData, amount, parameters);
        emit LoadedFromUser(assetData, amount, parameters);
    }

    function loadFromPosition(
        bytes calldata assetData,
        uint256 amount,
        bytes calldata parameters
    ) external payable override nonReentrant {
        _loadFromPosition(assetData, amount, parameters);
        emit LoadedFromPosition(assetData, amount, parameters);
    }

    function unloadToUser(
        bytes calldata assetData,
        uint256 amount,
        bytes calldata parameters
    ) external override nonReentrant {
        _unloadToUser(assetData, amount, parameters);
        emit UnloadedToUser(assetData, amount, parameters);
    }

    function unloadToPosition(
        address position,
        bytes calldata assetData,
        uint256 amount,
        bytes calldata parameters
    ) external override onlyRole(C.BOOKKEEPER_ROLE) {
        _unloadToPosition(position, assetData, amount, parameters);
        emit UnloadedToPosition(position, assetData, amount, parameters);
    }

    function _loadFromUser(bytes memory assetData, uint256 amount, bytes memory parameters) internal virtual;

    function _loadFromPosition(bytes memory assetData, uint256 amount, bytes memory parameters) internal virtual;

    function _unloadToUser(bytes memory assetData, uint256 amount, bytes memory parameters) internal virtual;

    function _unloadToPosition(
        address position,
        bytes memory assetData,
        uint256 amount,
        bytes memory parameters
    ) internal virtual;
}