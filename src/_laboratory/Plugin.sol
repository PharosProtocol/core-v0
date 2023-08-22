// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// NOTE this was intended to house logic shared between all plugin categories. However, there
//      turned out not to be any shared logic.

/*
import {Asset} from "src/libraries/LibUtils.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";

abstract contract Plugin {
    // /// @dev Not intended to be used for verification on-chain.
    // // function canHandleAssetAsset(Asset asset, bytes calldata parameters) view virtual returns (bool);

    // // /// @notice return the types of assets that are compatible to be loaned using this plugin.
    // // /// @dev if asset address is not populated it is assumed all assets of that standard are compatible.
    // // // Asset[] public COMPATIBLE_LOAN_ASSETS;
    // function canHandleAssetLoanAsset(Asset asset, bytes calldata parameters) external view virtual returns (bool);

    // // /// @notice return the types of assets that are compatible to be collateral using this plugin.
    // // /// @dev if asset address is not populated it is assumed all assets of that standard are compatible.
    // // // Asset[] public COMPATIBLE_COLL_ASSETS;
    // // /// @notice Return true if asset is compatible as collateral with the plugin.
    // function canHandleAssetCollAsset(Asset asset, bytes calldata parameters) external view\ virtual returns (bool);

    // function canHandleAsset(Asset calldata loanAsset, Asset calldata collAsset, bytes calldata parameters)
    //     external
    //     view
    //     virtual
    //     returns (bool);

    // // NOTE not using this, bc we assume cost asset == loan asset. May change someday though.
    // Asset[] immutable COMPATIBLE_COST_ASSETS;

    // constructor(Asset[] calldata compatibleLoanAssets, Asset[] calldata compatibleCollAssets) {
    //     COMPATIBLE_LOAN_ASSETS = compatibleLoanAssets;
    //     COMPATIBLE_COLL_ASSETS = compatibleCollAssets;
    // }

    // ex) if using a liquidator that passes all collateral to account then it should verify account can handle the
    // collateral asset at agreement time.
    /// @notice Perform any setup checks to ensure the plugin is compatible with agreement. Optional.
    /// @dev After agreement has been defined, should be able to verify off-chain to avoid gas cost.
    function initCheck(Agreement calldata agreement, bytes calldata parameters) external view {}

    // // If an asset can be used with the exposed interface functions of the plugin instance.
    // function isCompatibleAsset(Asset calldata asset, bytes calldata parameters) external view virtual;
}
*/
