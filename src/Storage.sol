// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

contract Storage {


    struct InstructionsParameters {
        address collateralAsset;
        uint256 maxLoanDurationHours;
        uint256 loanFeeRatio;
        uint256 hourlyInterestRatio;
        uint256 profitShareRatio;
        uint32[] whitelistedTerminalIds;
    }

    struct TerminalParameters {}


}
