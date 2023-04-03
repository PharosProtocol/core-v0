// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {IComparableParameters} from "src/modules/IComparableParameters.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
    uint256 id; // 721, 1155
    bytes data; // 721, 1155
}

struct IndexPair {
    uint128 offer;
    uint128 request;
}

struct ModuleReference {
    address addr;
    bytes parameters;
}

library Utils {
    /// @notice transfer ETH, ERC20, ERC721, ERC1155 tokens. ETH can only be sent from self.
    /// @dev modules do not need to use this function. It is provided as a qol helper for what is expected to be the
    ///      majority of implementations. Support for additional standards can be implemented on a per module basis.
    function transferAsset(address from, address to, Asset memory asset, uint256 amount) internal {
        if (isEth(asset)) {
            require(from == address(this), "transferAsset: ETH cannot be sent by third party");
            payable(to).transfer(amount);
        } else if (asset.standard == ERC20_STANDARD) {
            require(IERC20(asset.addr).transferFrom(from, to, amount));
        } else if (asset.standard == ERC721_STANDARD) {
            // TODO implement
            revert("not yet implemented");
            // IERC721(asset.addr).safeTransferFrom(address(this), msg.sender, asset.id);
        } else if (asset.standard == ERC1155_STANDARD) {
            // TODO implement
            revert("not yet implemented");
            // IERC1155(asset.addr).safeTransferFrom(address(this), msg.sender, asset.id, amount, asset.data);
        } else {
            revert("transferAsset: unsupported asset");
        }
    }

    function isEqModuleRef(ModuleReference calldata module0, ModuleReference calldata module1)
        public
        pure
        returns (bool)
    {
        if (module0.addr != module1.addr) return false;
        if (keccak256(module0.parameters) != keccak256(module1.parameters)) return false;
        return true;
    }

    function isInRange(uint256 value, uint256[2] calldata range) public pure returns (bool) {
        return range[0] <= value && value <= range[1];
    }

    function isInRangePair(uint256 value, uint256[2] calldata range0, uint256[2] calldata range1)
        external
        pure
        returns (bool)
    {
        return isInRange(value, range0) && isInRange(value, range1);
    }

    function isInRange(ModuleReference calldata module, ModuleReference[2] calldata range) public pure returns (bool) {
        if (!(module.addr == range[0].addr && module.addr == range[1].addr)) return false;
        IComparableParameters iModule = IComparableParameters(module.addr);
        return (
            iModule.isLTE(range[0].parameters, module.parameters)
                && iModule.isLTE(module.parameters, range[1].parameters)
        );
    }

    function isInRangePair(
        ModuleReference calldata module,
        ModuleReference[2] calldata range0,
        ModuleReference[2] calldata range1
    ) external pure returns (bool) {
        return isInRange(module, range0) && isInRange(module, range1);
    }

    // NOTE unclear if components of calldata can be passed around as calldata. will be too expensive here if this
    //      requires storage array arguments.
    function isSameAllowedModuleRef(
        IndexPair calldata idx,
        ModuleReference[] calldata offerAllowed,
        ModuleReference[] calldata requestAllowed
    ) external pure returns (bool) {
        return isEqModuleRef(offerAllowed[idx.offer], requestAllowed[idx.request]);
    }

    // NOTE is there an efficiency loss when calldata is passed in here as memory?
    function isEth(Asset memory asset) public pure returns (bool) {
        return asset.standard == ETH_STANDARD;
    }
}
