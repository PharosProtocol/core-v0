// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Assessor} from "src/modules/assessor/Assessor.sol";

/**
 * AaveAssessor is one possible implementation of how an assessor can be implemented to pool user assets.
 * This particular implementation uses the current static interest rate from Aave protocol.
 * Notable limitation of replication:
 *   - Aave interest rates are derived from their utilization, which may not match the utilization of this accounts.
 */
abstract contract AaveAssessor is Assessor {}
