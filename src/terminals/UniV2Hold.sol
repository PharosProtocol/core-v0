// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import {PositionFactory} from "src/modulus/PositionFactory.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

interface IUniV2HoldTerminal {
    function enter(uint256 amountIn, uint256 amountOutMin, address[] calldata path, uint256 deadline) external;
    function exit(uint256 amountIn, uint256 amountOutMin, address[] calldata path, uint256 deadline)
        external
        returns (uint256);
    function getPositionValue(uint256 amountIn, address[] calldata path) external returns (uint256);
}

/*
 * This contract serves as a demonstration of how to implement a Modulus Terminal.
 * Terminals should be deisgned as Minimal Proxy Contracts with an arbitrary number of proxy contracts. Each MPC
 * represents one position that has been open through the Terminal. This allows for the capital of multiple positions
 * to remain isolated from each other even when deployed in the same terminal.
 *
 * The Terminal must implement at minimum the set of methods shown in the Modulus Terminal Interface. Beyond that,
 * a terminal can offer an arbitrary set of additional methods that act as wrappers for the underlying protocol;
 * however, the Modulend marketplace cannot be updated to support all possible actions in all possible terminals. Users
 * will automatically have the ability to call functions listed in the interface as well as any public functions that do
 * not require arguments. These additional argumentless function calls can be used to wrap functionality of the
 * underlying protocol to enable simple updating and interaction with a position - we recommend they are named in a
 * self documenting fashion, so that users can be programatically informed of their purpose. Further,
 * arbitrarily complex functions can be implemented, but the terminal creator will be responsible for providing a UI
 * to handle these interactions.
 */
contract UniV2HoldTerminal is IUniV2HoldTerminal, PositionFactory {
    address public constant UNI_V2_ROUTER02 = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    constructor() {}

    /// Everything below executed using state of clone (Position).

    event UniV2HoldPositionEntered(address asset, uint256 amount);
    event UniV2HoldPositionExited(address asset, uint256 amount);

    // TODO: Should pass in args as bytes and decode them here if call is expected to come from modulus.
    // NOTE: What if enter is triggered by Lender (or anyone else but borrower) and they set amountOutMin very low to
    //       create sandwhich opportunity or increase odds of liquidation? Could even do it in a loop to drain all
    //       Request capital to 0.
    function enter(uint256 amountIn, uint256 amountOutMin, address[] calldata path, uint256 deadline)
        external
        override
        onlyRole(PROTOCOL_ROLE)
    {
        IERC20 assetERC20 = IERC20(path[0]);
        assetERC20.approve(UNI_V2_ROUTER02, amountIn); // msg.sender == modulus contract

        IUniswapV2Router02 router = IUniswapV2Router02(UNI_V2_ROUTER02);
        uint256[] memory outAmounts =
            router.swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), deadline); // msg.sender from router pov is clone (Position) address
        emit UniV2HoldPositionEntered(path[path.length - 1], outAmounts[outAmounts.length - 1]);
    }

    // TODO: can add recipient in certain scenarios to save an ERC20 transfer.
    function exit(uint256 amountIn, uint256 amountOutMin, address[] calldata path, uint256 deadline)
        external
        override
        onlyRole(PROTOCOL_ROLE)
        returns (uint256)
    {
        IERC20 assetERC20 = IERC20(path[0]);
        assetERC20.approve(UNI_V2_ROUTER02, amountIn); // msg.sender == modulus contract

        IUniswapV2Router02 router = IUniswapV2Router02(UNI_V2_ROUTER02);
        uint256[] memory outAmounts =
            router.swapExactTokensForTokens(amountIn, amountOutMin, path, PROTOCOL_ADDRESS, deadline); // msg.sender from router pov is clone (Position) address
        emit UniV2HoldPositionExited(path[path.length - 1], outAmounts[outAmounts.length - 1]); // gAs OpTiMIzaTiOn - not all this data is necessary, just need to know position at address X is closed
        return outAmounts[outAmounts.length - 1];
    }

    // Public Helpers.
    function getPositionValue(uint256 amountIn, address[] calldata path) external view override returns (uint256) {
        IUniswapV2Router02 router = IUniswapV2Router02(UNI_V2_ROUTER02);
        uint256[] memory outAmounts = router.getAmountsOut(amountIn, path);
        return outAmounts[outAmounts.length - 1];
    }
}
