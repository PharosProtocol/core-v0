// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {ITractor} from "@tractor/ITractor.sol";
import {SignedBlueprint} from "@tractor/Tractor.sol";

import {Fill, Order} from "src/libraries/LibBookkeeper.sol";

interface IBookkeeper is ITractor {
    function signPublishOrder(Order calldata order, uint256 endTime) external;

    function fillOrder(Fill calldata fill, SignedBlueprint calldata orderBlueprint) external;

    function closePosition(SignedBlueprint calldata agreementBlueprint) external payable;
    
    function unwindPosition(SignedBlueprint calldata agreementBlueprint) external payable;

    function triggerLiquidation(SignedBlueprint calldata agreementBlueprint, bytes calldata liquidatorLogic) external;
}
