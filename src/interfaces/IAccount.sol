// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// import {Agreement} from "src/libraries/LibBookkeeper.sol";


// Accounts are used to hold user capital to fill outstanding orders.
// assetData type is unique to each account plugin.

interface IAccount {
    /// @notice Transfer asset and increment account balance. Pulls asset from sender or uses msg.value.
    function loadFromUser(bytes calldata assetData, uint256 amount, bytes calldata accountParameters ) external payable;

    /// @notice Transfer asset and increment account balance. Pulls asset from sender or uses msg.value.
    /// @dev Assets may not literally be coming from a position.
    function loadFromPosition(bytes calldata assetData, uint256 amount, bytes calldata accountParameters) external payable;

    /// @notice Transfer asset and increment account balance. Pulls asset from sender or uses msg.value.
    function loadFromLiquidator(address liquidator, bytes calldata assetData, uint256 amount, bytes calldata accountParameters) external payable;

    /// @notice Transfer asset out and decrement account balance. Pushes asset to sender.
    function unloadToUser(bytes calldata assetData, uint256 amount, bytes calldata accountParameters, bytes calldata borrowerAssetData) external;

    /// @notice Transfer loan or collateral asset from account to Position MPC. Pushes.
    function unloadToPosition( address position, bytes calldata assetData, uint256 amount, bytes calldata accountParameters, bytes calldata borrowerAssetData) external;

    // NOTE is is possible to (securely) require the owner addr to be the first parameter so that owner can
    // be determined without external calls? To save gas.
    function getOwner(bytes calldata accountParameters) external view returns (address);

    function getBalance(bytes calldata assetData, bytes calldata accountParameters) external view returns (uint256);

}
