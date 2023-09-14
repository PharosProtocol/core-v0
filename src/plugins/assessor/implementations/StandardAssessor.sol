// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Assessor} from "../Assessor.sol";
import {IOracle} from "src/interfaces/IOracle.sol";
import {IPosition} from "src/interfaces/IPosition.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";

contract StandardAssessor is Assessor {
    struct Parameters {
        uint256 originationFeeValue; // Expected in loan asset units (e.g., if ETH, then 2 means 2 ETH)
        uint256 originationFeePercentage; // Expected as a whole number percentage (e.g., 2 means 2%)
        uint256 interestRate; // Expected as a whole number percentage
        uint256 profitShareRate; // Expected as a whole number percentage
    }

    function _getCost(
        Agreement calldata agreement
    ) internal view override returns (uint256 amount) {
        Parameters memory params = abi.decode(agreement.assessor.parameters, (Parameters));

        // Use oracle to get the value conversion

        uint256 resistantValue = IOracle(agreement.loanOracle.addr).getOpenPrice( agreement.loanOracle.parameters);
        uint256 spotValue = IOracle(agreement.loanOracle.addr).getClosePrice( agreement.loanOracle.parameters);
        uint256 higherValue = resistantValue > spotValue ? resistantValue : spotValue;
        
        // Get currentAmount from position and convert to loanAsset
        uint256 closeAmount = (IPosition(agreement.position.addr).getCloseAmount(agreement.position.parameters))/higherValue;

        // Calculate origination fee as value + percentage of loan amount
        uint256 originationFee = params.originationFeeValue + (agreement.loanAmount * params.originationFeePercentage / 100);

        // Calculate interest over time
        uint256 interest = agreement.loanAmount * (block.timestamp - agreement.deploymentTime) * params.interestRate / 100;

        // Calculate lender amount
        uint256 lenderAmount = originationFee + interest + agreement.loanAmount;

        // Calculate profit share
        uint256 profitShare = closeAmount > lenderAmount ? (closeAmount - lenderAmount) * params.profitShareRate / 100 : 0;

        // Total cost
        uint256 totalCost = originationFee + interest + profitShare;

    
        return totalCost * higherValue;
    }
}
