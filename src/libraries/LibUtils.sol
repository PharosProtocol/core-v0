// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IAccount} from "src/interfaces/IAccount.sol";
import {IndexPair, ModuleReference} from "src/libraries/LibBookkeeper.sol";

// Significant security risk to represent eth this way? Could wrap it instead.
// https://twitter.com/pashovkrum/status/1637722714772258817?s=20
bytes3 constant ETH_STANDARD = bytes3(uint24(1));
bytes3 constant ERC20_STANDARD = bytes3(uint24(20));
bytes3 constant ERC721_STANDARD = bytes3(uint24(721));
bytes3 constant ERC1155_STANDARD = bytes3(uint24(1155));

/// @notice Represents a single type of asset. Notice that standard = 1 represents ETH.
///         Designed initially to support ETH, ERC20, ERC721, ERC1155. May work for others.
struct Asset {
    bytes3 standard; // id of token standard. Using ERC#, but can be arbitrary.
    address addr;
    uint8 decimals; // 20
    uint256 id; // 721, 1155
    bytes data; // 721, 1155, arbitrary
}

library LibUtils {
    // NOTE is there an efficiency loss when calldata is passed in here as memory?
    function isEth(Asset memory asset) internal pure returns (bool) {
        return asset.standard == ETH_STANDARD;
    }

    /// @notice checks if address contains a deployed contract.
    /// @dev if the address is currently executing its constructor it will return true here. Do not use for security.
    function isDeployedContract(address addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(addr)
        }
        return (size > 0);
    }

    function addWithMsg(uint256 l, uint256 r, string memory failMsg) internal pure returns (uint256) {
        unchecked {
            require(l <= type(uint256).max - r, failMsg);
            return l + r;
        }
    }

    function subWithMsg(uint256 l, uint256 r, string memory failMsg) internal pure returns (uint256) {
        require(l >= r, failMsg);
        unchecked {
            return l - r;
        }
    }
}
 