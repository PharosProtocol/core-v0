// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

/*
 * A parameterized module is a module which uses a specific set of parameters in its calculations. These parameters
 * are the only distinction between instances and thus the parameters can be used to compare instances. Unique
 * instances are not created for each parameter; instead, the full set of parameters is encoded into orders and
 * positions. This allows for a single contract of each type to be used for all possible instances.
 */

interface IComparableParameters {
    /// @dev Assumes bytes are both defined for the same type of parameterized module.
    function isGTE(bytes calldata parameters0, bytes calldata parameters1) external pure returns (bool);
    /// @dev Assumes bytes are both defined for the same type of parameterized module.
    function isLTE(bytes calldata parameters0, bytes calldata parameters1) external pure returns (bool);
}
