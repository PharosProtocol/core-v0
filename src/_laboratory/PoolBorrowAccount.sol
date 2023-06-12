// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Account} from "src/modules/account/Account.sol";

/**
 * PoolBorrowAccount is one possible implementation of an account.
 * This particular implementation is used for pooling many users assets for use as collateral when in a borrow
 * agreement.
 *
 * Notable limitations:
 *  - How to fairly distribute rewards to users who were in for the appropriate time frame vs late joiners?
 */

abstract contract PoolBorrowAccount is Account {}
