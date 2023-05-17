// // SPDX-License-Identifier: UNLICENSED

// pragma solidity 0.8.19;

// import {Asset} from "src/LibUtil.sol";
// import {IHandler} from "../IHandler.sol";

// /*
//  * Asset handler exists to standardize pushing assets in a Pharos compatible manner. Functions should all be called
//  * as delegatecalls.
//  */

// contract ERC20Handler is IHandler {
//     // function pushAssetToAccount(address accountAddr, bytes accountParameters, Asset asset, uint256 amount) external {
//     //     (bool lenderSuccess,) = accountAddr.delegatecall(
//     //         abi.encodeWithSignature(
//     //             "loadPush((bytes3,address,uint256,bytes),uint256,bytes)", asset, amount, accountParameters
//     //         )
//     //     );
//     //     require(lenderSuccess, "ERC20Handler loadPush failed");
//     // }

//     function pushAssetToAddress(address addr, Asset asset, uint256 amount) external {
//         require(IERC20(asset.addr).transfer(to, amount), "ERC20Handler transfer failed");
//     }
// }
