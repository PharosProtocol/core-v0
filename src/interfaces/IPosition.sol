// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {IAccessControl} from "lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {Asset} from "src/libraries/LibUtil.sol";

/*
 * Each Position represents one deployment of capital through a factory.
 * Position status is determined by address assignment to ADMIN_ROLE.
 */

interface IPosition is IAccessControl {
    /// @notice Deploy capital into the defined position.
    function deploy(Asset calldata asset, uint256 amount, bytes calldata parameters) external;
    /// @notice Admin close position and optionally distribute assets back to agreement accounts.
    /// @notice Distribute assets to appropriate Accounts/wallets. Give control to borrower.
    /// @dev Guarantees enough asset to pay lender bc it will be taken from sender.
    function close(address sender, Agreement memory agreement, bool distribute, bytes calldata parameters)
        external
        returns (uint256);
    /// @notice Transfer the position to a new controller. Used for liquidations.
    /// @dev Do not set admin role to prevent liquidator from pushing the position back into the protocol.
    function transferContract(address controller) external;
    /// @notice Get current exitable value of the position, denoted in loan asset.
    function getCloseAmount(bytes calldata parameters) external view returns (uint256);

    function canHandleAsset(Asset calldata asset, bytes calldata parameters) external pure returns (bool);
    /// @notice Pass through function to allow the position to interact with other contracts after liquidation.
    /// @dev Internal functions are not reachable. // NOTE right? bc allowing controller to be set *back* to bookkeeper will open exploits
    function passThrough(address payable destination, bytes calldata data, bool delegateCall)
        external
        payable
        returns (bool, bytes memory);
    // function removeEth(address payable recipient) external // ONLY_ROLE(BOOKKEEPER_ROLE)
}
