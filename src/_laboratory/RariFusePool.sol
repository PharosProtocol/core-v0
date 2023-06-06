// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Account} from "src/modules/account/Account.sol";

/**
 * RariFusePool is one possible implementation of how an account can be implemented to pool user assets.
 * This particular implementation is intended to replicate the isolated supply pool system of Rari Fuse.
 * Each pool can contain multiple assets, rewards to suppliers are distributed per asset, proportionally to all
 * pooled suppliers of that asset.
 * Notable limitation of replication:
 *   - Dynamic interest rates are not yet implemented.
 *   - Unclear how to distribute profits to earlier suppliers when a new supplier enters. How did Rari?
 */
abstract contract RariFusePool is Account {}
