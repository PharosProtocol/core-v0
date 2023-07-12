// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {Asset} from "src/libraries/LibUtils.sol";

/**
 * Accounts are used to hold user capital to back outstanding unfilled orders.
 *
 * Implementation Restrictions:
 *   - All accounts must be able to receive ETH and ERC20s on behalf of a user (defined via parameters).
 *     This is necessary to enable payment and receipt of Assessor defined costs, which will always be denoted
 *     in either ETH or ERC20.
 */

// Accounts are responsible for abstracting complex assets, which brings in a lot more complexity. A position
// does not need to understand how to work with its collateral asset, thus it can be entirely arbitrary.
// Should loan asset comprehension be encoded into the factory though? Since most will be definition have to
// be specifically compatible with the asset they are utilizing...

// Do not use address type for assets because it limits what can be represented (i.e. ERC-721 tokenId is a uint256)
// YET it seems that the orderbook itself must be able to generate the arguments of the below functions, otherwise
// there is no way to verify the arguments are compatible with the orders/agreement. Will I just need to accept that
// the interfaces cannot be fully generalized? on principle bc they must be comprehensible enough to determine
// compatibility between all module calls and the orders.
// This catch22 probably applies to all modules interfaces...

// There is a lot of complexity at position closure (happy or liquidation) bc there are 2 assets moving and both may
// not be compatible with both accounts. This results in assets being sent to account owners, which actually breaks
// the abstraction of Accounts replacing addresses. Previously did not want to require both accounts to be compatible
// with both assets, bc it significantly tightens compatibility matrix when using niche assets and fractures supply.
// Realizing now that using owner wallet will not be possible when Account represents a pool.
//
// Logic will actually be a lot simpler if we can remove Load methods and instead do direct sends based on asset type.
// Balances can be verified directly. Assume each account is exactly 1 user and abstraction always holds. Do not allow
// borrower accounts to be used if they cannot handle the borrowed asset (lender accounts do not need to be compatible
// with collateral? or do they if they are using a liquidator that passes collateral to lender?). Ok tight compatibility
// may be long term challenging but will make design much easier. May embrace it.
// Actually, if using direct sends do accounts need any sense of compatibility? Can argue it is account manager's
// responsibility to be able to withdraw any assets they find at the address.
//
// ^^ in follow up to this implemented the optional initCheck() method for Modules.

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
