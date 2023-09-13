// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;


interface IOracle {
    /// @notice manipulation-resistant price.
    function getResistantValue(uint256 amount, bytes calldata parameters) external view returns (uint256 ethAmount);

    /// @notice spot price. 
    function getSpotValue(uint256 amount, bytes calldata parameters) external view returns (uint256 ethAmount);

}
