// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

contract Storage {


    struct InstructionSetParameters {
        address collateralAsset;
        uint256 maxLoanDurationHours;
        uint256 loanFeeRatio;
        uint256 hourlyInterestRatio;
        uint256 profitShareRatio;
        uint32[] whitelistedTerminalIds;
    }

    struct TerminalParameters {}

    struct Position {
        uint32 positionId;
        address borrowerId;
        address terminalId;
        uint256 creationTime;
        uint256 inputAmount; // Is this ok type for all reasonable token Decimal configurations?
        uint256 liquidationPositionPrice;
    }

}

