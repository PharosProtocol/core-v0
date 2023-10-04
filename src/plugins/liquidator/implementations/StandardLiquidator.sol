// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {C} from "src/libraries/C.sol";
import {ILiquidator} from "src/interfaces/ILiquidator.sol";
import {Liquidator} from "../Liquidator.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {IPosition} from "src/interfaces/IPosition.sol";


contract StandardLiquidator is Liquidator {

    struct Parameters {
        // all inputs use 18 decimal precision
        uint256 fixedFee; // Expected in loan asset units (e.g., if ETH, then 2e18 means 2 ETH)
        uint256 percentageFee; // Expected as a whole number percentage (e.g., 2e18 means 2%)
    }

    function _getReward(
        Agreement calldata agreement
    ) internal view override returns (uint256 amount){
    Parameters memory params = abi.decode(agreement.liquidator.parameters, (Parameters));

    uint256 closeAmount = (IPosition(agreement.position.addr).getCloseAmount(agreement));
    uint256 reward = params.fixedFee + (params.percentageFee*closeAmount)/(100*C.RATIO_FACTOR);

    return reward;

    }
}
