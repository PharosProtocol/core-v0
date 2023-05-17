// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Asset} from "src/LibUtil.sol";

contract Module {
    /// @notice return the types of assets that are compatible to be loaned using this module.
    /// @dev if asset address is not populated it is assumed all assets of that standard are compatible.
    Asset[] COMPATIBLE_LOAN_ASSETS;

    /// @notice return the types of assets that are compatible to be collateral using this module.
    /// @dev if asset address is not populated it is assumed all assets of that standard are compatible.
    Asset[] COMPATIBLE_COLL_ASSETS;

    // // NOTE not using this, bc we assume cost asset == loan asset. May change someday though.
    // Asset[] immutable COMPATIBLE_COST_ASSETS;

    // constructor(Asset[] calldata compatibleLoanAssets, Asset[] calldata compatibleCollAssets) {
    //     COMPATIBLE_LOAN_ASSETS = compatibleLoanAssets;
    //     COMPATIBLE_COLL_ASSETS = compatibleCollAssets;
    // }
}
