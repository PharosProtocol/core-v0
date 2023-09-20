// // SPDX-License-Identifier: MIT

// pragma solidity 0.8.19;

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {ISwapRouter} from "@uni-v3-periphery/interfaces/ISwapRouter.sol";
// import {BytesLib} from "@uni-v3-periphery/libraries/BytesLib.sol";
// import {Path} from "@uni-v3-periphery/libraries/Path.sol";
// import {CallbackValidation} from "@uni-v3-periphery/libraries/CallbackValidation.sol";

// import {IAccount} from "src/interfaces/IAccount.sol";
// import {C} from "src/libraries/C.sol";
// import {LibUniswapV3} from "src/libraries/LibUniswapV3.sol";
// import {Asset, ERC20_STANDARD} from "src/libraries/LibUtils.sol";
// import {LibUtilsPublic} from "src/libraries/LibUtilsPublic.sol";
// import {Agreement} from "src/libraries/LibBookkeeper.sol";
// import {Position} from "src/plugins/position/Position.sol";

// struct SwapCallbackData {
//     bytes path;
//     address payer;
// }

// /*
//  * This contract serves as a demonstration of how to implement a Terminal / Factory.
//  * Factories should be designed as Minimal Proxy Contracts with an arbitrary number of proxy contracts. Each MPC
//  * represents one position that has been open through the Factory. This allows for the capital of multiple positions
//  * to remain isolated from each other even when deployed in the same Factory.
//  *
//  * The Factory must implement at minimum the set of methods shown in the Factory Interface. Beyond that,
//  * a Factory can offer an arbitrary set of additional methods that act as wrappers for the underlying protocol;
//  * however, the Plugin marketplace cannot be updated to support all possible actions in all possible Factory. Users
//  * will automatically have the ability to call functions listed in the interface as well as any public functions that do
//  * not require parameters. These additional argumentless function calls can be used to wrap functionality of the
//  * underlying protocol to enable simple updating and interaction with a position - we recommend they are named in a
//  * self documenting fashion, so that users can be programatically informed of their purpose. Further,
//  * arbitrarily complex functions can be implemented, but the Factory creator will be responsible for providing a UI
//  * to handle these interactions.
//  */

// // NOTE for sake of efficiency, should split into multi-hop and single pool paths.

// contract UniV3HoldFactory is Position {
//     struct Parameters {
//         bytes enterPath;
//         bytes exitPath;
//     }

//     // SECURITY what is a safe enough twap time at expected volumes?
//     uint32 private constant TWAP_TIME = 300;
//     uint256 private constant DEADLINE_OFFSET = 180;
//     uint256 private constant STEP_SLIPPAGE_RATIO = C.RATIO_FACTOR / 200; // 0.5% slippage

//     // Position state
//     uint256 private amountHeld;

//     using Path for bytes;
//     using BytesLib for bytes;

//     constructor(address protocolAddr) Position(protocolAddr) {}

//     function canHandleAsset(Asset calldata asset, bytes calldata parameters) external pure override returns (bool) {
//         Parameters memory params = abi.decode(parameters, (Parameters));
//         if (asset.standard != ERC20_STANDARD) return false;
//         // if (params.enterPath.numPools() > 1) return false;
//         // if (params.exitPath.numPools() > 1) return false;
//         if (asset.addr != params.enterPath.toAddress(0)) return false;
//         if (asset.addr != params.exitPath.toAddress(params.exitPath.length - 20)) return false;
//         return true;
//     }

//     /**
//      * @notice Send ERC20 assets that Uniswap expects for swap.
//      * @dev see lib/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol
//      * @param   amount0Delta 0 represents pool index (not directionality)
//      * @param   amount1Delta 1 represents pool index (not directionality)
//      * @param   _data  .
//      */
//     function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata _data) external {
//         SwapCallbackData memory swapCallbackData = abi.decode(_data, (SwapCallbackData));
//         require(swapCallbackData.payer == address(this), "USTCBIP");
//         (address tokenIn, address tokenOut, uint24 fee) = swapCallbackData.path.decodeFirstPool(); // Token order is directionality?
//         CallbackValidation.verifyCallback(C.UNI_V3_FACTORY, tokenIn, tokenOut, fee); // requires sender == pool

//         // Uniswap V3 gas optimization is just pushing gas, along with complexity, onto protocol users. <3
//         uint256 amountToPay;
//         if (amount0Delta > 0) {
//             amountToPay = uint256(amount0Delta);
//             require(tokenIn < tokenOut, "USTCBTOI0"); // Must be exact input with tokenIn as token0
//         } else if (amount1Delta > 0) {
//             amountToPay = uint256(amount1Delta);
//             require(tokenIn > tokenOut, "USTCBTOI1"); // Must be exact input with tokenIn as token1
//         } else {
//             revert("USTCBZAMS");
//         }

//         LibUtilsPublic.safeErc20Transfer(tokenIn, address(msg.sender), amountToPay);
//     }

//     /// @dev assumes assets are already in Position.
//     function _deploy(Asset calldata asset, uint256 amount, bytes calldata parameters) internal override {
//         Parameters memory params = abi.decode(parameters, (Parameters));
//         // verifyAssetAllowed(asset); // NOTE should check that asset is match to path.
//         ISwapRouter router = ISwapRouter(C.UNI_V3_ROUTER);

//         require(asset.standard == ERC20_STANDARD, "UniV3Hold: asset must be ERC20");
//         IERC20(asset.addr).approve(C.UNI_V3_ROUTER, amount); // NOTE front running?

//         // NOTE can use ExactInput instead to support single hop trades w/o worry for path.
//         // ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter.ExactInputSingleParams({
//         //     path: params.enterPath,
//         //     recipient: address(this), // position address
//         //     deadline: block.timestamp + DEADLINE_OFFSET,
//         //     amountIn: amount,
//         //     amountOutMinimum: (
//         //         LibUniswapV3.getPathTWAP(params.enterPath, amount, TWAP_TIME) * STEP_SLIPPAGE_RATIO
//         //             * params.enterPath.numPools()
//         //         ) / C.RATIO_FACTOR
//         // });
//         // amountHeld = router.exactInputSingle(swapParams); // msg.sender from router pov is clone (Position) address

//         ISwapRouter.ExactInputParams memory swapParams = ISwapRouter.ExactInputParams({
//             path: params.enterPath,
//             recipient: address(this), // position address
//             deadline: block.timestamp + DEADLINE_OFFSET,
//             amountIn: amount,
//             amountOutMinimum: amountOutMin(params)
//         });
//         amountHeld = router.exactInput(swapParams); // msg.sender from router pov is clone (Position) address
//     }

//     function _close(address, Agreement calldata agreement) internal override returns (uint256 closedAmount) {
//         Parameters memory params = abi.decode(agreement.position.parameters, (Parameters));
//         // require(heldAsset.standard == ERC20_STANDARD, "UniV3Hold: exit asset must be ETH or ERC20");
//         (address heldAsset, , ) = params.exitPath.decodeFirstPool();

//         uint256 transferAmount = amountHeld;
//         amountHeld = 0;

//         // Approve ERC20s.
//         IERC20(heldAsset).approve(C.UNI_V3_ROUTER, transferAmount); // NOTE front running?

//         // TODO: can add recipient in certain scenarios to save an ERC20 transfer.
//         {
//             ISwapRouter router = ISwapRouter(C.UNI_V3_ROUTER);
//             ISwapRouter.ExactInputParams memory swapParams = ISwapRouter.ExactInputParams({
//                 path: params.exitPath,
//                 recipient: address(this), // position address
//                 deadline: block.timestamp + DEADLINE_OFFSET,
//                 amountIn: transferAmount,
//                 amountOutMinimum: amountOutMin(params)
//             });
//             closedAmount = router.exactInput(swapParams); // msg.sender from router pov is clone (Position) address
//         }
//     }

//     function _distribute(address sender, uint256 lenderAmount, Agreement calldata agreement) internal override {
//         IERC20 erc20 = IERC20(agreement.loanAsset.addr);
//         uint256 balance = erc20.balanceOf(address(this));

//         // If there are not enough assets to pay lender, pull missing from sender.
//         if (lenderAmount > balance) {
//             LibUtilsPublic.safeErc20TransferFrom(
//                 agreement.loanAsset.addr,
//                 sender,
//                 address(this),
//                 lenderAmount - balance
//             );
//             balance += lenderAmount - balance;
//         }

//         if (lenderAmount > 0) {
//             // SECURITY account plugin cannot trust terminal plugin account to use loadFromPosition over loadFromUser.
//             //          must ensure assets of non-involved parties are at risk if a hostile terminal used.
//             erc20.approve(agreement.lenderAccount.addr, lenderAmount);
//             IAccount(agreement.lenderAccount.addr).loadFromPosition(
//                 agreement.loanAsset,
//                 lenderAmount,
//                 agreement.lenderAccount.parameters
//             );
//             balance -= lenderAmount;
//         }

//         // Send borrower loan asset funds to their account. Requires compatibility btwn loan asset and borrow account.
//         if (balance > 0) {
//             erc20.approve(agreement.borrowerAccount.addr, balance);
//             IAccount(agreement.borrowerAccount.addr).loadFromPosition(
//                 agreement.loanAsset,
//                 balance,
//                 agreement.borrowerAccount.parameters
//             );
//         }
//         // Collateral is still in borrower account and is unlocked by the bookkeeper.
//     }

//     // Public Helpers.

//     function _getCloseAmount(bytes calldata parameters) internal view override returns (uint256) {
//         Parameters memory params = abi.decode(parameters, (Parameters));
//         // (,address finalAssetAddr,) = params.exitPath.decodeFirstPool();
//         // require(asset.addr == finalAssetAddr); // by this point it is too late to be checking honestly.
//         return amountOutMin(params);
//     }

//     // NOTE this is an inexact method of computing multistep slippage. but exponentials are hard.
//     function amountOutMin(Parameters memory params) private view returns (uint256) {
//         return
//             (LibUniswapV3.getPathTWAP(params.exitPath, amountHeld, TWAP_TIME) *
//                 (C.RATIO_FACTOR - STEP_SLIPPAGE_RATIO * params.exitPath.numPools())) / C.RATIO_FACTOR;
//     }
// }
