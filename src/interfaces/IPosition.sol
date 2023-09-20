// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {Asset} from "src/libraries/LibUtils.sol";

/*
 * Each Position represents one deployment of capital through a factory.
 * The Position and all of its assets are fully under the control of the admin role. Expected admins are the
 * the bookkeeper during healthy deployment, the borrower after happy close, the liquidator plugin during
 * liquidation, and the liquidator user after successful liquidation.
 */

interface IPosition is IAccessControl {
    /// @notice Deploy capital into the defined position.
    /// @dev Called at thee implementation contract (terminal).
    function deploy(Asset calldata asset, uint256 amount, bytes calldata parameters) external;

    /// @notice Admin close position and leave assets in position MPC contract.
    function close(address sender, Agreement calldata agreement) external returns (uint256);

    /// @notice Distribute the loan asset to the lender and borrower. Assumes position has been closed already.
    /// @notice Lender account receives set amount and borrower receives all remaining asset in contract.
    /// @dev If there is not enough in contract to pay lender amount, take from sender wallet.
    function distribute(address sender, uint256 lenderAmount, Agreement calldata agreement) external payable;

    /// @notice Get current exitable value of the position, denoted in loan asset.
    /// @notice Value is an estimate. Value at exit may differ slightly.
    function getCloseAmount(bytes calldata parameters) external view returns (uint256);

    /// @notice Transfer the position to a new controller. Used for liquidations.
    /// @dev Do not set admin role to prevent liquidator from pushing the position back into the protocol.
    function transferContract(address controller) external;

    function canHandleAsset(Asset calldata asset, bytes calldata parameters) external pure returns (bool);

    // SECURITY is it correct that internal/private functions cannot be reached with this passthrough?
    /// @notice Pass through function to allow the position to interact with other contracts after liquidation.
    /// @dev Internal functions are not reachable.
    /// @dev Refer to LibUtilsPublic for common functionality.
    function passThrough(
        address payable destination,
        bytes calldata data,
        bool delegateCall
    ) external payable returns (bool, bytes memory);
}
