// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Agreement} from "src/bookkeeper/LibBookkeeper.sol";
import {IAccount} from "src/modules/account/IAccount.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IAccessControl} from "lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {IAssessor} from "src/modules/assessor/IAssessor.sol";
import {C} from "src/C.sol";
import "src/LibUtil.sol";

/*
 * Each Position represents one deployment of capital through a Terminal.
 * Position status is determined by address assignment to CONTROLLER_ROLE.
 */
interface IPosition is IAccessControl {
    function enter(Asset calldata asset, uint256 amount, bytes calldata parameters) external;
    /// @notice Get current exitable value of the position, denoted in loan asset.
    function getExitAmount(Asset calldata asset, bytes calldata parameters) external view returns (uint256);
    /// @notice Wind down and return assets to appropriate Accounts.
    function exit(Agreement memory agreement, bytes calldata parameters) external returns (uint256); // onlyRole(CONTROLLER_ROLE)
    /// @notice Transfer the position to a new controller. Used for liquidations.
    /// @dev do not set admin role to prevent liquidator from pushing the position back into the protocol.
    function transferContract(address controller) external; // onlyRole(CONTROLLER_ROLE)
    /// @notice Pass through function to allow the position to interact with other contracts after liquidation.
    function passThrough(address payable destination, bytes calldata data)
        external
        payable
        returns (bool, bytes memory); // onlyRole(CONTROLLER_ROLE)
        // function removeEth(address payable recipient) external // ONLY_ROLE(BOOKKEEPER_ROLE)
}

abstract contract Position is AccessControl, IPosition {
    event ControlTransferred(address indexed previousController, address indexed newController);

    function enter(Asset calldata asset, uint256 amount, bytes calldata parameters)
        external
        override
        onlyRole(C.CONTROLLER_ROLE)
    {
        _enter(asset, amount, parameters);
    }

    function _enter(Asset calldata asset, uint256 amount, bytes calldata parameters) internal virtual;

    // AUDIT Hello auditors, pls gather around. This feels risky.
    function transferContract(address controller) external override onlyRole(C.CONTROLLER_ROLE) {
        // grantRole(LIQUIDATOR_ROLE, controller); // having a distinct liquidator role and controller role is a nicer abstraction, but has gas cost for no benefit.
        grantRole(C.CONTROLLER_ROLE, controller);
        renounceRole(C.CONTROLLER_ROLE, address(this));

        // TODO fix this so that admin role is not granted to untrustable code (liquidator user or module). Currently
        // will get stuck as liquidator module will not be able to grant liquidator control.
        // Do not allow liquidators admin access to avoid security implications if set back to protocol control.
        // if (grantAdmin) {
        //     grantRole(DEFAULT_ADMIN_ROLE, controller);
        // }
        // renounceRole(DEFAULT_ADMIN_ROLE);
        emit ControlTransferred(msg.sender, controller);
    }

    function exit(Agreement memory agreement, bytes calldata parameters)
        external
        override
        onlyRole(C.CONTROLLER_ROLE)
        returns (uint256 unpaidAmount)
    {
        uint256 lenderAmount;
        uint256 borrowerAmount;
        uint256 exitedAmount = _exit(agreement.loanAsset, parameters);

        // Lender gets loan asset back to account.
        uint256 lenderOwed = agreement.loanAmount + IAssessor(agreement.assessor.addr).getCost(agreement);
        if (lenderOwed > exitedAmount) {
            // Lender is owed more than the position is worth.
            // Lender gets all of the position and borrower pays the difference.
            unpaidAmount = lenderOwed - exitedAmount;
            lenderAmount = exitedAmount;
            borrowerAmount = 0;
        } else {
            unpaidAmount = 0;
            lenderAmount = lenderOwed;
            borrowerAmount = exitedAmount - lenderOwed;
        }

        if (lenderAmount > 0) {
            // Abstracting asset movement logic into account avoids need for knowledge of asset transfer details here.
            // Delegate calling to a third party contract is v dangerous, but they only have access to the state of
            // this position, which was created with explicit agreement by both parties to allow the account contract.
            (bool lenderSuccess,) = agreement.lenderAccount.addr.delegatecall(
                abi.encodeWithSignature(
                    "loadPush((bytes3,address,uint256,bytes),uint256,bytes)",
                    agreement.loanAsset,
                    lenderAmount,
                    agreement.lenderAccount.parameters
                )
            );
            require(lenderSuccess, "failed to loadPush into lender account");
        }

        // // If borrower account can handle asset, return assets to account.
        if (borrowerAmount > 0) {
            //     if (IAccount(agreement.borrowerAccount).isCompatible(agreement.loanAsset, agreement.borrowerAccount.parameters)) {
            //         (bool success,) = agreement.borrowerAccount.addr.delegatecall(
            //             abi.encodeWithSignature(
            //                 "loadPush((bytes3,address,uint256,bytes),uint256,bytes)",
            //                 agreement.loanAsset,
            //                 borrowerAmount,
            //                 agreement.borrowerAccount.parameters
            //             )
            //         );
            //     // Borrower gets remaining loan asset direct to wallet that took the position
            //     } else {

            // (bool success,) = agreement.lenderAccount.addr.delegatecall(
            //     abi.encodeWithSignature(
            //         "throughPush(address,(bytes3,address,uint256,bytes),uint256)",
            //         IAccount(agreement.borrowerAccount.addr).getOwner(agreement.borrowAccount.parameters),
            //         agreement.loanAsset,
            //         borrowerAmount
            //     )
            // );
            _transferAsset(
                payable(IAccount(agreement.borrowerAccount.addr).getOwner(agreement.borrowerAccount.parameters)),
                agreement.loanAsset,
                borrowerAmount
            );
            // NOTE are there assets that could fail and lock here? Like safe erc721 transfer with callback
            // require(success, "failed to throughPush to borrower");
        }

        // Borrower gets full collateral back to account. Notice that position does not need to understand collateral
        // asset or how to transfer.

        // if (agreement.collateralAmount > 0) {

        // IAccount(agreement.borrowerAccount.addr).load{
        //     value: Utils.isEth(agreement.collateralAsset) ? agreement.collateralAmount : 0
        // }(agreement.collateralAsset, agreement.collateralAmount, agreement.borrowerAccount.parameters);

        (bool borrowerSuccess,) = agreement.borrowerAccount.addr.delegatecall(
            abi.encodeWithSignature(
                "loadPush((bytes3,address,uint256,bytes),uint256,bytes)",
                agreement.collateralAsset,
                agreement.collateralAmount,
                agreement.borrowerAccount.parameters
            )
        );
        require(borrowerSuccess, "failed to loadPush into lender account");

        // NOTE should bookkeeper renounce control of empty position? positions shouldn't have any approved spending, so seems without risk.
        // renounceRole(C.CONTROLLER_ROLE, address(this));
        // renounceRole(DEFAULT_ADMIN_ROLE); // this isn't necessary as the immutable contract provably cannot abuse this. No trust needed.
    }

    function _exit(Asset memory exitAsset, bytes calldata parameters) internal virtual returns (uint256);

    function _transferAsset(address payable to, Asset memory asset, uint256 amount) internal virtual;

    function passThrough(address payable destination, bytes calldata data)
        external
        payable
        onlyRole(C.CONTROLLER_ROLE)
        returns (bool, bytes memory)
    {
        return destination.call{value: msg.value}(data);
    }
}
