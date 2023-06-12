// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Order} from "src/bookkeeper/LibBookkeeper.sol";

interface IBookkeeper {
    function signPublishOrder(Order calldata order, uint256 endTime) external;
}
