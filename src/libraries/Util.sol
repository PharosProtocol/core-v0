// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

struct IndexPair {
    uint128 offer;
    uint128 request;
}

struct ModuleReference {
    address addr;
    bytes parameters;
}

library Utils {
    function isSameModuleReference(ModuleReference memory module0, ModuleReference memory module1)
        external
        pure
        returns (bool)
    {
        if (module0.addr != module1.addr) return false;
        if (keccak256(module0.parameters) != keccak256(module1.parameters)) return false;
        return true;
    }
}
