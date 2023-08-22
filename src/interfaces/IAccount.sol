// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {Asset, PluginRef} from "src/libraries/LibUtils.sol";

// NOTE cannot allow callers to define an arbitrary freighter, unless they full own the account.

interface IAccount {
    /// @notice Transfer asset into account. Pulls.
    /// @dev Asset processing is called after completion of load().
    function load(
        address from,
        PluginRef calldata freighter,
        Asset calldata asset,
        uint256 amount,
        bytes calldata parameters
    ) external payable;

    /// @notice Transfer asset out of account. Pushes.
    function unload(
        address to,
        PluginRef calldata freighter,
        Asset calldata asset,
        uint256 amount,
        bytes calldata parameters
    ) external;

    /// @notice Transfer loan or collateral asset from account to Position MPC. Pushes.
    function sendToPosition(
        address to,
        PluginRef calldata freighter,
        Asset calldata asset,
        uint256 amount,
        bytes calldata parameters
    ) external;

    function owner() external view returns (address);

    // NOTE the same asset could be represented with different hashes. this seems risky.
    // oh its actually a much larger problem... that probably already existed
    // using creative plugins and asset configuration a user could get around the lock on their collateral.
    // solutions....?
    // - pair 1 freighter to each account. same for terminals. ?
    // - move collateral assets to position at agreement time
    //     - could indicate collateral vs loan asset when moving and then restake etc
    // - let the freighter handle locking/unlocking and all balance logic
    // identify asset (lock balance) using asset config + freighter address

    // ^^ think there is a fundamental logic flaw by assuming balance cannot be tracked but locked balance out to be

    // ^^ there is also a unique issue at play here where there is a reason for a user to want to steal their own
    //     funds (i.e. collateral in use) and those funds could be affected by other agreements that were not
    //     involving the original counter party that will be in trouble with disappearing collateral

    // ... ok i give in to the obviously optimal design - all assets go to terminal clone!

    // function lockAsset(bytes32 assetHash, uint256 amount, bytes calldata parameters) external;

    // function unlockAsset(bytes32 assetHash, uint256 amount, bytes calldata parameters) external;

    // function getUnlockedBalance(Asset calldata asset, bytes calldata parameters) external view returns (uint256);
}
