// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import {Terminal} from "src/modulus/Terminal.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

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
contract CurveEthTerminal is Terminal {
    // Assets that can be used to open a Position.
    // address[2] public constant ALLOWED_ASSETS = [address(0x3), address(0x4)]; // ERC20 addresses
    bytes public constant ALLOWED_ASSETS = abi.encodePacked([address(0x3), address(0x4)]); // ERC20 addresses
    // address[2] public constant ASSET_POOLS = [address(0x31), address(0x41)]; // Curve pool addresses
    bytes public constant ASSET_POOLS = abi.encodePacked([address(0x31), address(0x41)]); // Curve pool addresses
    // address[2] public constant ETH_INDICES = [0, 1]; // Index of Eth within 2 sided pool.
    bytes public constant ETH_INDICES = abi.encodePacked([0, 1]); // Index of Eth within 2 sided pool.
    // ^^ is this byte packing and iterating doing what I think?

    address public enterAsset;
    uint256 public ethAmount;

    function enter(address asset, uint256 amount) internal override onlyRole(PROTOCOL_ROLE) {
        // Can only enter a unique position one time.
        require(enterAsset == address(0));
        require(asset != address(0));
        enterAsset = asset;

        (address pool, uint256 index) = _getAssetPoolAndEthIndex();
        _swapToEth(pool, index, amount);
    }

    function exit() external override onlyRole(PROTOCOL_ROLE) returns (uint256 exitAmount) {
        (address pool, uint256 index) = _getAssetPoolAndEthIndex();
        exitAmount = _swapFromEth(pool, index);
        require(IERC20(enterAsset).transfer(PROTOCOL_ADDRESS, exitAmount));
        // require(IERC20(enterAsset).transfer(msg.sender, exitAmount)); // better practice with clones?
    }

    function _getAssetPoolAndEthIndex() public view returns (address, uint256) {
        address[2] memory allowed_assets = abi.decode(ALLOWED_ASSETS, (address[2]));
        address[2] memory asset_pools = abi.decode(ASSET_POOLS, (address[2]));
        uint256[2] memory eth_indicies = abi.decode(ETH_INDICES, (uint256[2]));
        for (uint256 i; i < allowed_assets.length; i++) {
            if (enterAsset == address(allowed_assets[i])) {
                return (asset_pools[i], eth_indicies[i]);
            }
        }
        // // NOTE: I assume this is more efficient than decoding each array, but can't slice in memory. y.
        // for (uint256 i; i < ALLOWED_ASSETS.length; i += 20) {
        //     if (enterAsset == address(ALLOWED_ASSETS[i:i + 20])) {
        //         return (ASSET_POOLS[i:i + 20], ETH_INDICES[i:i + 20]);
        //     }
        // }
        revert();
    }

    function _swapToEth(address pool, uint256 eth_idx, uint256 amount) private {}

    function _swapFromEth(address pool, uint256 eth_idx) private returns (uint256 amount) {}
    
    // Public Helpers.
    function getAllowedAssets() external pure override returns (address[] memory) {
        // NOTE: decoding to dynamic size array is ok?
        address[] memory allowed_assets = abi.decode(ALLOWED_ASSETS, (address[]));
        return allowed_assets;
    }

    function getPositionValue() external view override returns (address asset, uint256 amount) {}
}
