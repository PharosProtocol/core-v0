// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// import {Agreement} from "src/bookkeeper/LibBookkeeper.sol";
import {Asset} from "src/LibUtil.sol";

/**
 * Accounts are used to hold user capital to back outstanding unfilled orders.
 */

// Do not use address type for assets because it limits what can be represented (i.e. ERC-721 tokenId is a uint256)
// YET it seems that the orderbook itself must be able to generate the arguments of the below functions, otherwise
// there is no way to verify the arguments are compatible with the orders/agreement. Will I just need to accept that
// the interfaces cannot be fully generalized? on principle bc they must be comprehensible enough to determine
// compatibility between all module calls and the orders.
// This catch22 probably applies to all modules interfaces...

interface IAccount {
    // NOTE using a "from" system is vulnerable to callers pulling on victim approvals into their own accounts.
    //      could use a preload / presend concept?
    // function addAssetFrom(address from, Asset calldata asset, uint256 amount, bytes calldata parameters)
    /// NOTE that handling of eth in this function, which cannot be third party transferred, seems very ugly.
    /// @notice Transfer and add asset to account. Uses msg.value if asset is ETH.
    function addAsset(Asset calldata asset, uint256 amount, bytes calldata parameters) external payable; // is it necessary to specify payable here? some impls may not accept eth
    function addAssetBookkeeper(address from, Asset calldata asset, uint256 amount, bytes calldata parameters)
        external
        payable; // onlyRole(BOOKKEEPER_ROLE)
    function removeAsset(Asset calldata asset, uint256 amount, bytes calldata parameters) external;

    // // NOTE these helpers are not useable internally due to Solidity restrictions on dynamic memory arrays.
    // function addAssets(Asset[] calldata assets, uint256[] calldata amount, bytes calldata parameters)
    //     external
    //     payable; // is it necessary to specify payable here? some impls may not accept eth
    // function removeAssets(Asset[] calldata assets, uint256[] calldata amount, bytes calldata parameters) external;

    // NOTE Sending collateral to position contract for now. May not be strictly necessary.
    // function capitalizePosition(Agreement calldata agreement) external returns; // onlyRole(BOOKKEEPER_ROLE)
    function capitalizePosition(
        address position,
        Asset calldata loanAsset,
        uint256 loanAmount,
        bytes calldata lenderAccountParameters,
        Asset calldata collateralAsset,
        uint256 collateralAmount,
        bytes calldata borrowerAccountParameters
    ) external; // onlyRole(BOOKKEEPER_ROLE)

    // NOTE third party addAsset, used in liquidations. Is there any reason to not just use addAssets?
    // function returnAsset(address asset, uint256 amount, bytes calldata parameters) external;

    // NOTE do pure functions actually make an external call to existing contracts? If so, this is gas inefficient.
    function getOwner(bytes calldata parameters) external view returns (address);
    function getBalance(Asset calldata asset, bytes calldata parameters) external view returns (uint256);
}
