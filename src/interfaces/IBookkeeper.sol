// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Fill, Order} from "src/libraries/LibBookkeeper.sol";
import {ITractor} from "lib/tractor/ITractor.sol";
import {SignedBlueprint} from "lib/tractor/Tractor.sol";

interface IBookkeeper is ITractor {
    function signPublishOrder(Order calldata order, uint256 endTime) external;
    function fillOrder(Fill calldata fill, SignedBlueprint calldata orderBlueprint) external;
    function exitPosition(SignedBlueprint calldata agreementBlueprint) external payable;
    function kick(SignedBlueprint calldata agreementBlueprint) external;
}
