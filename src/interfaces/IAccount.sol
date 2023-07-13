// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {Asset} from "src/libraries/LibUtils.sol";

/**
 * Accounts are used to hold user capital to fill outstanding orders.
 *
 * Implementation Restrictions:
 *   - All accounts must be able to receive ETH and ERC20s (defined via parameters).
 *     This is necessary to enable payment and receipt of Assessor defined costs, which will always be denoted
 *     in either ETH or ERC20.
 */

interface IAccount {
    /// @notice Transfer asset and increment account balance. Pulls asset from sender or uses msg.value.
    function loadFromUser(Asset calldata asset, uint256 amount, bytes calldata parameters) external payable;

    /// @notice Transfer asset and increment account balance. Pulls asset from sender or uses msg.value.
    /// @dev Assets may not literally be coming from a position.
    function loadFromPosition(Asset calldata asset, uint256 amount, bytes calldata parameters) external payable;

    /// @notice Transfer asset out and decrement account balance. Pushes asset to sender.
    function unloadToUser(Asset calldata asset, uint256 amount, bytes calldata parameters) external;

    /// @notice Transfer loan or collateral asset from account to Position MPC. Pushes.
    function unloadToPosition(
        address position,
        Asset calldata asset,
        uint256 amount,
        bool isLockedColl,
        bytes calldata parameters
    ) external;

    function lockCollateral(Asset calldata asset, uint256 amount, bytes calldata parameters) external;

    function unlockCollateral(Asset calldata asset, uint256 amount, bytes calldata parameters) external;

    // NOTE is is possible to (securely) require the owner addr to be the first parameter so that owner can
    // be determined without external calls? To save gas.
    function getOwner(bytes calldata parameters) external view returns (address);

    function getBalance(Asset calldata asset, bytes calldata parameters) external view returns (uint256);

    function canHandleAsset(Asset calldata asset, bytes calldata parameters) external view returns (bool);
}
