// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {C} from "src/libraries/C.sol";
import {IAccount} from "src/interfaces/IAccount.sol";


abstract contract Account is IAccount, AccessControl, ReentrancyGuard {
    event LoadedFromUser(bytes assetData, uint256 amount, bytes accountParameters);
    event LoadedFromPosition(bytes assetData, uint256 amount, bytes accountParameters);
    event LoadedFromLiquidator(address liquidator, bytes assetData, uint256 amount, bytes parameters);
    event UnloadedToUser(bytes assetData, uint256 amount, bytes parameters, bytes borrowerAssetData);
    event UnloadedToPosition(address position, bytes assetData, uint256 amount, bytes parameters, bytes borrowerAssetData);

    constructor(address bookkeeperAddr) {
        _setupRole(C.BOOKKEEPER_ROLE, bookkeeperAddr);
    }

    function loadFromUser(
        bytes calldata assetData,
        uint256 amount,
        bytes calldata accountParameters
    ) external payable override nonReentrant {
        _loadFromUser(assetData, amount, accountParameters );
        emit LoadedFromUser(assetData, amount, accountParameters);
    }


    function loadFromPosition(
        bytes calldata assetData,
        uint256 amount,
        bytes calldata accountParameters
    ) external payable override nonReentrant {
        _loadFromPosition(assetData, amount, accountParameters) ;
        emit LoadedFromPosition(assetData, amount, accountParameters );
    }

    function loadFromLiquidator(
        address liquidator,
        bytes calldata assetData,
        uint256 amount,
        bytes calldata accountParameters
    ) external payable override nonReentrant {
        _loadFromLiquidator(liquidator, assetData, amount, accountParameters);
        emit LoadedFromLiquidator(liquidator, assetData, amount, accountParameters);
    }



    function unloadToUser(
        bytes calldata assetData,
        uint256 amount,
        bytes calldata accountParameters,
        bytes calldata borrowerAssetData
    ) external override nonReentrant {
        _unloadToUser(assetData, amount, accountParameters,borrowerAssetData);
        emit UnloadedToUser(assetData, amount, accountParameters,borrowerAssetData);
    }

    function unloadToPosition(
        address position,
        bytes calldata assetData,
        uint256 amount,
        bytes calldata accountParameters,
        bytes calldata borrowerAssetData
    ) external override onlyRole(C.BOOKKEEPER_ROLE) {
        _unloadToPosition(position, assetData, amount, accountParameters,borrowerAssetData);
        emit UnloadedToPosition(position, assetData, amount, accountParameters,borrowerAssetData);
    }



    function _loadFromUser(bytes memory assetData, uint256 amount, bytes memory accountParameters) internal virtual;
    function _loadFromPosition(bytes memory assetData, uint256 amount, bytes memory accountParameters) internal virtual;

    function _loadFromLiquidator(address liquidator, bytes memory assetData, uint256 amount, bytes memory accountParameters) internal virtual;
    function _unloadToUser(bytes memory assetData, uint256 amount, bytes memory accountParameters,bytes memory borrowerAssetData) internal virtual;
    function _unloadToPosition(address position, bytes memory assetData, uint256 amount, bytes memory accountParameters, bytes memory borrowerAssetData ) internal virtual;

}