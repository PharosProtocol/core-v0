// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWETH9 is IERC20 {
    /// @notice Deposit eth to get wether
    function deposit() external payable;

    /// @notice Withdraw weth to get eth
    function withdraw(uint256) external;
}
