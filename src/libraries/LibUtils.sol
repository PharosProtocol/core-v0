// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IAccount} from "src/interfaces/IAccount.sol";
import {IndexPair, PluginReference} from "src/libraries/LibBookkeeper.sol";

// Significant security risk to represent eth this way? Could wrap it instead.
// https://twitter.com/pashovkrum/status/1637722714772258817?s=20
bytes3 constant ETH_STANDARD = bytes3(uint24(1));
bytes3 constant ERC20_STANDARD = bytes3(uint24(20));
bytes3 constant ERC721_STANDARD = bytes3(uint24(721));
bytes3 constant ERC1155_STANDARD = bytes3(uint24(1155));

struct Asset {
    bytes3 standard; // id of token standard.
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

    function addWithMsg(uint256 left, uint256 right, string memory failMsg) internal pure returns (uint256) {
        unchecked {
            require(left <= type(uint256).max - right, failMsg);
            return left + right;
        }
    }

    function subWithMsg(uint256 left, uint256 right, string memory failMsg) internal pure returns (uint256) {
        require(left >= right, failMsg);
        unchecked {
            return left - right;
        }
    }

    function isValidLoanAssetAsCost(Asset memory loanAsset, Asset memory costAsset) internal pure returns (bool) {
        if (loanAsset.standard != ERC20_STANDARD) return false;
        if (keccak256(abi.encode(loanAsset)) != keccak256(abi.encode(costAsset))) return false;
        return true;
    }
}
