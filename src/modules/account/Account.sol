// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

// import {Agreement} from "src/bookkeeper/LibBookkeeper.sol";
import "src/C.sol";
import {Asset} from "src/LibUtil.sol";
import {IAccount} from "src/interfaces/IAccount.sol";
import {Module} from "src/modules/Module.sol";

abstract contract Account is IAccount, AccessControl, Module {
    event Loaded(Asset asset, uint256 amount, bytes parameters);
    event Unloaded(Asset asset, uint256 amount, bytes parameters);
    event TransferredToPosition(address position, Asset asset, uint256 amount, bool isLockedAsset, bytes parameters);
    event Locked(Asset asset, uint256 amount, bytes parameters);
    event Unlocked(Asset asset, uint256 amount, bytes parameters);

    function load(Asset calldata asset, uint256 amount, bytes calldata parameters) external payable override {
        _load(asset, amount, parameters);
        emit Loaded(asset, amount, parameters);
    }

    function sideLoad(address from, Asset calldata asset, uint256 amount, bytes calldata parameters)
        external
        payable
        override
        onlyRole(C.BOOKKEEPER_ROLE)
    {
        return _sideLoad(from, asset, amount, parameters);
    }

    function unload(Asset calldata asset, uint256 amount, bytes calldata parameters) external override {
        _unload(asset, amount, parameters);
        emit Unloaded(asset, amount, parameters);
    }

    function transferToPosition(
        address position,
        Asset calldata asset,
        uint256 amount,
        bool isLockedAsset,
        bytes calldata parameters
    ) external override onlyRole(C.BOOKKEEPER_ROLE) {
        _transferToPosition(position, asset, amount, isLockedAsset, parameters);
        emit TransferredToPosition(position, asset, amount, isLockedAsset, parameters);
    }

    function lockCollateral(Asset calldata asset, uint256 amount, bytes calldata parameters)
        external
        override
        onlyRole(C.BOOKKEEPER_ROLE)
    {
        _lockCollateral(asset, amount, parameters);
        emit Locked(asset, amount, parameters);
    }

    function unlockCollateral(Asset calldata asset, uint256 amount, bytes calldata parameters)
        external
        override
        onlyRole(C.BOOKKEEPER_ROLE)
    {
        _unlockCollateral(asset, amount, parameters);
        emit Unlocked(asset, amount, parameters);
    }

    function _load(Asset calldata asset, uint256 amount, bytes calldata parameters) internal virtual;
    function _sideLoad(address from, Asset calldata asset, uint256 amount, bytes calldata parameters)
        internal
        virtual;
    function _unload(Asset calldata asset, uint256 amount, bytes calldata parameters) internal virtual;
    function _transferToPosition(
        address position,
        Asset calldata asset,
        uint256 amount,
        bool isLockedAsset,
        bytes calldata parameters
    ) internal virtual;
    function _lockCollateral(Asset calldata asset, uint256 amount, bytes calldata parameters) internal virtual;
    function _unlockCollateral(Asset calldata asset, uint256 amount, bytes calldata parameters) internal virtual;
}
