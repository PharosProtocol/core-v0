// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Agreement} from "src/libraries/LibBookkeeper.sol";

//Assessors are used to determine the cost a borrower must pay to the lender for a loan.
 
interface IAssessor {
    /// @notice Returns the cost of a loan (not including principle)
    function getCost(
        Agreement calldata agreement
    ) external  returns ( uint256 amount);
}
