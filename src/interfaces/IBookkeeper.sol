// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {ITractor} from "@tractor/ITractor.sol";
import {SignedBlueprint} from "@tractor/Tractor.sol";

import {Fill, Order} from "src/libraries/LibBookkeeper.sol";

interface IBookkeeper is ITractor {
    function signPublishOrder(Order calldata order, uint256 endTime) external;

    function loadAccount() external;

    function unloadAccount() external;

    function fillOrder(Fill calldata fill, SignedBlueprint calldata orderBlueprint) external;

    function exitPosition(SignedBlueprint calldata agreementBlueprint) external payable;

    function kick(SignedBlueprint calldata agreementBlueprint) external;
}
