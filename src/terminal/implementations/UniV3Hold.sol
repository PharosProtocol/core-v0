// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "forge-std/console.sol";

import {IAccount} from "src/modules/account/IAccount.sol";
import {C} from "src/C.sol";
import {Position} from "src/terminal/Position.sol";
import {Asset, ETH_STANDARD, ERC20_STANDARD} from "src/LibUtil.sol";
import {Module} from "src/modules/Module.sol";
import {IAssessor} from "src/modules/assessor/IAssessor.sol";
import {Agreement} from "src/bookkeeper/LibBookkeeper.sol";

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "src/interfaces/IWETH9.sol";
import {ISwapRouter} from "lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "lib/v3-periphery/contracts/libraries/PoolAddress.sol";
import "lib/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "lib/v3-core/contracts/libraries/TickMath.sol";
import "lib/v3-core/contracts/libraries/FixedPoint96.sol";
import "lib/v3-core/contracts/libraries/FullMath.sol";
import "lib/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "lib/v3-periphery/contracts/interfaces/IQuoter.sol";

import "lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {BytesLib} from "lib/v3-periphery/contracts/libraries/BytesLib.sol";
import {Path} from "lib/v3-periphery/contracts/libraries/path.sol";
import {IUniswapV3Factory} from "lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {CallbackValidation} from "lib/v3-periphery/contracts/libraries/CallbackValidation.sol";

import {LibUniswapV3} from "src/util/LibUniswapV3.sol";

// import {SwapCallbackData} from "lib/v3-periphery/contracts/SwapRouter.sol";
struct SwapCallbackData {
    bytes path;
    address payer;
}

// import "lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";

// (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

/*
 * This contract serves as a demonstration of how to implement a Modulus Terminal.
 * Terminals should be designed as Minimal Proxy Contracts with an arbitrary number of proxy contracts. Each MPC
 * represents one position that has been open through the Terminal. This allows for the capital of multiple positions
 * to remain isolated from each other even when deployed in the same terminal.
 *
 * The Terminal must implement at minimum the set of methods shown in the Modulus Terminal Interface. Beyond that,
 * a terminal can offer an arbitrary set of additional methods that act as wrappers for the underlying protocol;
 * however, the Modulend marketplace cannot be updated to support all possible actions in all possible terminals. Users
 * will automatically have the ability to call functions listed in the interface as well as any public functions that do
 * not require parameters. These additional argumentless function calls can be used to wrap functionality of the
 * underlying protocol to enable simple updating and interaction with a position - we recommend they are named in a
 * self documenting fashion, so that users can be programatically informed of their purpose. Further,
 * arbitrarily complex functions can be implemented, but the terminal creator will be responsible for providing a UI
 * to handle these interactions.
 *
 * NOTE for sake of efficiency, should split into multi-hop and single pool paths.
 */
contract UniV3HoldTerminal is Position, Module {
    struct Parameters {
        bytes enterPath;
        bytes exitPath;
    }

    address public constant UNI_V3_FACTORY = address(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    address public constant UNI_V3_ROUTER = address(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    // Terminal parameters shared for all positions.
    // NOTE sharing params here increases simplicity but costs position customizability. how much of a burden is it to
    //      have very large parameters set in each order? that will probably dictate how we want to handle this.
    //      Also, setting them here prevents a position creator from setting them in a hostile fashion.
    uint32 private constant TWAP_TIME = 300; // https://oracle.euler.finance
    uint256 private constant DEADLINE_OFFSET = 180;
    uint256 private constant STEP_SLIPPAGE_RATIO = C.RATIO_FACTOR / 1000; // 0.1% slippage ?

    // Position state
    uint256 private amountHeld;

    using Path for bytes;
    using BytesLib for bytes;

    constructor(address protocolAddr) Position(protocolAddr) 
    // Component(compatibleLoanAssets, compatibleCollAssets)
    {
        COMPATIBLE_LOAN_ASSETS.push(Asset({standard: ERC20_STANDARD, addr: address(0), id: 0, data: ""}));
        COMPATIBLE_COLL_ASSETS.push(Asset({standard: ERC20_STANDARD, addr: address(0), id: 0, data: ""}));
    }

    /**
     * @notice Send ERC20 assets that Uniswap expects for swap.
     * @dev see lib/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol
     * @param   amount0Delta 0 represents pool index (not directionality)
     * @param   amount1Delta 1 represents pool index (not directionality)
     * @param   _data  .
     */
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata _data) external {
        SwapCallbackData memory swapCallbackData = abi.decode(_data, (SwapCallbackData));
        require(swapCallbackData.payer == address(this), "USTCBIP");
        (address tokenIn, address tokenOut, uint24 fee) = swapCallbackData.path.decodeFirstPool(); // Token order is directionality?
        CallbackValidation.verifyCallback(UNI_V3_FACTORY, tokenIn, tokenOut, fee); // requires sender == pool

        // Uniswap V3 gas optimization is just pushing gas, along with complexity, onto protocol users. <3
        uint256 amountToPay;
        if (amount0Delta > 0) {
            amountToPay = uint256(amount0Delta);
            require(tokenIn < tokenOut, "USTCBTOI0"); // Must be exact input with tokenIn as token0
        } else if (amount1Delta > 0) {
            amountToPay = uint256(amount1Delta);
            require(tokenIn > tokenOut, "USTCBTOI1"); // Must be exact input with tokenIn as token1
        } else {
            revert("USTCBZAMS");
        }

        require(IERC20(tokenIn).transfer(address(msg.sender), amountToPay), "USTCBTF");
    }

    /// @dev assumes assets are already in Position.
    function _deploy(Asset calldata asset, uint256 amount, bytes calldata parameters) internal override {
        Parameters memory params = abi.decode(parameters, (Parameters));
        // verifyAssetAllowed(asset); // NOTE should check that asset is match to path.
        ISwapRouter router = ISwapRouter(UNI_V3_ROUTER);

        // // NOTE is wrapping built into uni v3 at lib/v3-periphery/contracts/base/PeripheryPayments.sol ?
        // if (asset.standard == ETH_STANDARD) {
        //     IWETH9(C.WETH).deposit{value: amount}();
        //     IERC20(C.WETH).approve(UNI_V3_ROUTER, amount); // NOTE front running?
        // } else {
        require(asset.standard == ERC20_STANDARD, "UniV3Hold: asset must be ERC20");
        IERC20(asset.addr).approve(UNI_V3_ROUTER, amount); // NOTE front running?
        // }

        // NOTE can use ExactInput instead to support single hop trades w/o worry for path.
        // ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter.ExactInputSingleParams({
        //     path: params.enterPath,
        //     recipient: address(this), // position address
        //     deadline: block.timestamp + DEADLINE_OFFSET,
        //     amountIn: amount,
        //     amountOutMinimum: (
        //         LibUniswapV3.getPathTWAP(params.enterPath, amount, TWAP_TIME) * STEP_SLIPPAGE_RATIO
        //             * params.enterPath.numPools()
        //         ) / C.RATIO_FACTOR
        // });
        // amountHeld = router.exactInputSingle(swapParams); // msg.sender from router pov is clone (Position) address
        ISwapRouter.ExactInputParams memory swapParams = ISwapRouter.ExactInputParams({
            path: params.enterPath,
            recipient: address(this), // position address
            deadline: block.timestamp + DEADLINE_OFFSET,
            amountIn: amount,
            amountOutMinimum: amountOutMin(params)
        });
        amountHeld = router.exactInput(swapParams); // msg.sender from router pov is clone (Position) address

        // return amountHeld; // can a named return value be used with a state variable?
    }

    // NOTE: How to liquidate if min acceptable price is uncontrollable? Better to liquidate at a bad price now than wait
    //       until volatility slows. Answer: Allow liquidator to pass in min price, but require them to return some
    //       amount. then if they give themselves a bad deal they are the only one who loses. Alt Answer: Allow
    //       liquidator to pass through any function via callback, so long as they return enough assets to Modulend
    //       lender / borrower in end.
    function _exit(Agreement calldata agreement, bytes calldata parameters) internal override {
        Parameters memory params = abi.decode(parameters, (Parameters));
        // require(heldAsset.standard == ERC20_STANDARD, "UniV3Hold: exit asset must be ETH or ERC20");
        (address heldAsset,,) = params.exitPath.decodeFirstPool();

        uint256 transferAmount = amountHeld;
        amountHeld = 0;

        // Approve ERC20s.
        IERC20(heldAsset).approve(UNI_V3_ROUTER, transferAmount); // NOTE front running?

        // TODO: can add recipient in certain scenarios to save an ERC20 transfer.
        ISwapRouter router = ISwapRouter(UNI_V3_ROUTER);
        ISwapRouter.ExactInputParams memory swapParams = ISwapRouter.ExactInputParams({
            path: params.exitPath,
            recipient: address(this), // position address
            deadline: block.timestamp + DEADLINE_OFFSET,
            amountIn: transferAmount,
            amountOutMinimum: amountOutMin(params)
        });

        // console.log(IERC20(params.exitPath
        uint256 lenderOwed = agreement.loanAmount + IAssessor(agreement.assessor.addr).getCost(agreement);
        console.log("lenderOwed: %s", lenderOwed);
        uint256 borrowerAmount;
        IERC20 loanAsset = IERC20(address(agreement.loanAsset.addr));

        {
            // NOTE this is a bit weird, as get cost is imperfect and may not match current value to exitedAmount.
            uint256 exitedAmount = router.exactInput(swapParams); // msg.sender from router pov is clone (Position) address

            if (lenderOwed < exitedAmount) {
                borrowerAmount = exitedAmount - lenderOwed;
            } else {
                borrowerAmount = 0;
                // Lender is owed more than the position is worth.
                // Lender gets all of the position and borrower pays the difference.
                // NOTE could maybe save gas if account PushFrom implemented. Or some decoupling of transfer logic and incrementing.
                loanAsset.transferFrom(
                    IAccount(agreement.borrowerAccount.addr).getOwner(agreement.borrowerAccount.parameters),
                    address(this),
                    lenderOwed - exitedAmount
                );
            }
        }

        if (lenderOwed > 0) {
            loanAsset.approve(agreement.lenderAccount.addr, lenderOwed);
            IAccount(agreement.lenderAccount.addr).load(
                agreement.loanAsset, lenderOwed, agreement.lenderAccount.parameters
            );
        }

        // Send borrower loan asset funds to their wallet, bc it is unknown if compatible with collateral account.
        // Could require compatibility between loan asset and borrow account, but would cause unneeded compatibility
        // restrictions.
        if (borrowerAmount > 0) {
            require(
                loanAsset.transfer(
                    IAccount(agreement.borrowerAccount.addr).getOwner(agreement.borrowerAccount.parameters),
                    borrowerAmount
                ),
                "failed to transfer to borrower"
            );
        }

        // // Convert WETH to ETH.
        // if (exitAsset.standard == ETH_STANDARD) {
        //     IWETH9(C.WETH).withdraw(exitAmount);
        // }
    }

    // // Only used for transferring loan asset direct to user.
    // function _transferLoanAsset(address payable to, Asset memory asset, uint256 amount) internal override {
    //     if (asset.standard == ETH_STANDARD) {
    //         // NOTE change to call and protec
    //         to.transfer(amount);
    //     } else if (asset.standard == ERC20_STANDARD) {
    //         IERC20(asset.addr).transfer(to, amount);
    //     } else {
    //         revert("Incompatible asset");
    //     }
    // }

    // Public Helpers.

    // TODO fix this to be useable on chain efficiently
    function getExitAmount(bytes calldata parameters) external view override returns (uint256) {
        Parameters memory params = abi.decode(parameters, (Parameters));
        // (,address finalAssetAddr,) = params.exitPath.decodeFirstPool();
        // require(asset.addr == finalAssetAddr); // by this point it is too late to be checking honestly.
        return amountOutMin(params);
    }

    // NOTE this is an inexact method of computing multistep slippage. but exponentials are hard.
    function amountOutMin(Parameters memory params) private view returns (uint256) {
        return LibUniswapV3.getPathTWAP(params.exitPath, amountHeld, TWAP_TIME)
            * (C.RATIO_FACTOR - STEP_SLIPPAGE_RATIO * params.exitPath.numPools()) / C.RATIO_FACTOR;
    }

    // function AssetParameters(Asset asset) private view {
    //     require(asset.standard == ERC20_STANDARD);
    //     require(asset.addr == path[0th token]);
    // require paths to be compatible so no assets get stuck
    // (,address finalAssetAddr,) = params.exitPath.decodeFirstPool();
    // require(asset.addr == finalAssetAddr, "illegal exit path");
    // }
}
