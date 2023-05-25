// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Agreement} from "src/bookkeeper/LibBookkeeper.sol";
import {IAccessControl} from "lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {Asset} from "src/LibUtil.sol";

/*
 * Each Position represents one deployment of capital through a factory.
 * Position status is determined by address assignment to CONTROLLER_ROLE.
 */

interface IPosition is IAccessControl {
    /// @notice Deploy capital into the defined position.
    function deploy(Asset calldata asset, uint256 amount, bytes calldata parameters) external;
    /// @notice Get current exitable value of the position, denoted in loan asset.
    function getExitAmount(bytes calldata parameters) external view returns (uint256);
    /// @notice Borrower close of position
    /// @notice Distribute assets to appropriate Accounts/wallets. Give control to borrower.
    function exit(Agreement memory agreement, bytes calldata parameters) external; // onlyRole(CONTROLLER_ROLE)
    /// @notice Transfer the position to a new controller. Used for liquidations.
    /// @dev Do not set admin role to prevent liquidator from pushing the position back into the protocol.
    function transferContract(address controller) external; // onlyRole(CONTROLLER_ROLE)

    function isCompatible(Asset calldata loanAsset, bytes calldata parameters) external pure returns (bool);
    /// @notice Pass through function to allow the position to interact with other contracts after liquidation.
    /// @dev Internal functions are not reachable. // NOTE right? bc allowing controller to be set *back* to bookkeeper will open exploits
    function passThrough(address payable destination, bytes calldata data)
        external
        payable
        returns (bool, bytes memory); // onlyRole(CONTROLLER_ROLE)
        // function removeEth(address payable recipient) external // ONLY_ROLE(BOOKKEEPER_ROLE)
}
