// // SPDX-License-Identifier: MIT

// pragma solidity 0.8.19;

// import {C} from "src/libraries/C.sol";
// import {Oracle} from "../Oracle.sol";
// import {Asset} from "src/libraries/LibUtils.sol";

// /*
//  * Semi random oracle with price that deviates more dramatically with time.
//  */
// contract SpicyOracle is Oracle {
//     struct Parameters {
//         uint256 ratio;
//         uint256 initBlock;
//     }

//     function canHandleAsset(Asset calldata, bytes calldata) external pure override returns (bool) {
//         return true;
//     }

//     function getResistantValue(uint256 amount, bytes calldata parameters) external view returns (uint256) {
//         return _value(amount, parameters);
//     }

//     function getSpotValue(uint256 amount, bytes calldata parameters) external view returns (uint256) {
//         return _value(amount, parameters);
//     }

//     function getResistantAmount(uint256 ethAmount, bytes calldata parameters) external view returns (uint256) {
//         Parameters memory params = abi.decode(parameters, (Parameters));
//         return (_sauce(params.initBlock, false) * (ethAmount * params.ratio)) / (10 ** C.ETH_DECIMALS) / C.RATIO_FACTOR;
//     }

//     function _value(uint256 amount, bytes calldata parameters) private view returns (uint256) {
//         Parameters memory params = abi.decode(parameters, (Parameters));
//         return (_sauce(params.initBlock, true) * (amount * (10 ** C.ETH_DECIMALS))) / params.ratio / C.RATIO_FACTOR;
//     }

//     function _sauce(uint256 initBlock, bool value) private view returns (uint256) {
//         uint256 deltaBlocks = block.number - initBlock;
//         bool increasingValue = (initBlock % 2 == 0);

//         if ((value && increasingValue) || (!value && !increasingValue)) {
//             deltaBlocks += 1;
//             return C.RATIO_FACTOR + (C.RATIO_FACTOR * deltaBlocks) / 100; // increase by 1% every block
//         } else {
//             if (deltaBlocks > 100) return 0;
//             return (C.RATIO_FACTOR * (100 - deltaBlocks)) / 100; // decrease by 1% every block
//         }
//     }
// }
