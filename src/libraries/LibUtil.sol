// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import {IComparableModule} from "src/interfaces/IComparableModule.sol";

struct IndexPair {
    uint128 offer;
    uint128 request;
}

struct ModuleReference {
    address addr;
    bytes parameters;
}

library Utils {
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
        IComparableModule iModule = IComparableModule(module.addr);
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
}
