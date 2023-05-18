// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// import {Agreement} from "src/bookkeeper/LibBookkeeper.sol";
import {Asset} from "src/LibUtil.sol";

/**
 * Accounts are used to hold user capital to back outstanding unfilled orders.
 */

// Accounts are responsible for abstracting complex assets, which brings in a lot more complexity. A position
// does not need to understand how to work with its collateral asset, thus it can be entirely arbitrary.
// Should loan asset comprehension be encoded into the terminal though? Since most will be definition have to
// be specifically compatible with the asset they are utilizing...

// Do not use address type for assets because it limits what can be represented (i.e. ERC-721 tokenId is a uint256)
// YET it seems that the orderbook itself must be able to generate the arguments of the below functions, otherwise
// there is no way to verify the arguments are compatible with the orders/agreement. Will I just need to accept that
// the interfaces cannot be fully generalized? on principle bc they must be comprehensible enough to determine
// compatibility between all module calls and the orders.
// This catch22 probably applies to all modules interfaces...

interface IAccount {
    /// @notice Transfer asset and increment account balance. Pulls asset from sender or uses msg.value.
    function load(Asset calldata asset, uint256 amount, bytes calldata parameters) external payable;
    /// @notice Transfer asset from address and increment account balance. Pulls asset from sender or uses msg.value.
    function sideLoad(address from, Asset calldata asset, uint256 amount, bytes calldata parameters) external payable; // onlyRole(BOOKKEEPER_ROLE)
    /// @notice Push asset from msg.sender to account and increment account balance.
    /// @dev must use as delegatecall.
    function loadPush(Asset calldata asset, uint256 amount, bytes calldata parameters) external payable;
    // /// @notice Push asset from msg.sender to to. Do not increment account balance.
    // /// @dev must use as delegatecall.
    // function throughPush(address to, Asset calldata asset, uint256 amount) external payable;
    /// @notice Transfer asset out and decrement account balance. Pushes asset to sender.
    function unload(Asset calldata asset, uint256 amount, bytes calldata parameters) external;
    /// @notice Transfer loan or collateral asset from account to Position MPC. Pushes.
    function transferToPosition(
        address position,
        Asset calldata asset,
        uint256 amount,
        bool isLockedAsset,
        bytes calldata parameters
    ) external; // onlyRole(BOOKKEEPER_ROLE)
    function lockCollateral(Asset calldata asset, uint256 amount, bytes calldata parameters) external; // onlyRole(BOOKKEEPER_ROLE)
    function unlockCollateral(Asset calldata asset, uint256 amount, bytes calldata parameters) external; // onlyRole(BOOKKEEPER_ROLE)

    function getOwner(bytes calldata parameters) external view returns (address);
    function getBalance(Asset calldata asset, bytes calldata parameters) external view returns (uint256);
}
