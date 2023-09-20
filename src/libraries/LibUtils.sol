// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;


import {IAccount} from "src/interfaces/IAccount.sol";
import {IndexPair, PluginReference} from "src/libraries/LibBookkeeper.sol";


library LibUtils {

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

    // function isValidLoanAssetAsCost(Asset memory loanAsset, Asset memory costAsset) internal pure returns (bool) {
    //     if (loanAsset.standard != ERC20_STANDARD) return false;
    //     if (keccak256(abi.encode(loanAsset)) != keccak256(abi.encode(costAsset))) return false;
    //     return true;
    // }
}
