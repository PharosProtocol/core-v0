// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Assessor} from "src/modules/assessor/Assessor.sol";

/**
 * CompoundAssessor is one possible implementation of how an assessor can be implemented to pool user assets.
 * This particular implementation uses the current interest rate from Compound protocol.
 * Notable limitation of replication:
 *   - Compound interest rates are derived from their utilization, which may not match the utilization of accounts.
 */
abstract contract CompoundAssessor is Assessor {}
