// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

/// NOTE Could use a "Parent" system for the collections below. Thus when only wanting to create a collection with
///         one new item do not need to store all previous items as well. This would definitely reduce storage costs,
///         but it is not clear how it would affect lookup costs.
/*
 * ModuleCollections is a place to organize groups of modules for ease of use and to reduce duplicative storage.
 */

/*
 * An OracleFactory may be trusted, but the parameters provided to one of its instances may be hostile, so a user must
 * select exactly which Oracle instances they are willing to use. Rather than have each account store the same
 * mapping of addresses they can be grouped and found here.
 */
contract OracleSetCollection {
    struct OracleSet {
        bool exists;
        mapping(address => address) oracles; // asset address => oracle address
    }

    mapping(bytes32 => OracleSet) private oracleSets;

    event OracleSetStored(bytes32 indexed id, address[] assets, address[] oracles);

    function storeOracleSet(bytes32 id, address[] calldata assets, address[] calldata oracles) public {
        OracleSet storage oracleSet = oracleSets[id];
        require(!oracleSet.exists);
        oracleSet.exists = true;
        for (uint256 i; i < assets.length; i++) {
            oracleSet.oracles[assets[i]] = oracles[i];
        }
        emit OracleSetStored(id, assets, oracles);
    }

    // NOTE: best practice: return 0x0 address and assume the meanss DNE, or return additional bool?
    function getOracle(bytes32 id, address asset) external view returns (address) {
        return oracleSets[id].oracles[asset];
    }
}

contract TerminalSetCollection {
    struct TerminalSet {
        bool exists;
        mapping(address => bool) terminals;
    }

    mapping(bytes32 => TerminalSet) private terminalSets;

    event TerminalSetStored(bytes32 indexed id, address[] terminals);

    function storeTerminalSet(bytes32 id, address[] calldata terminals) public {
        require(!terminalSets[id].exists);
        for (uint256 i; i < terminals.length; i++) {
            terminalSets[id].terminals[terminals[i]] = true;
        }
        emit TerminalSetStored(id, terminals);
    }

    function isInTerminalSet(bytes32 id, address terminal) external view returns (bool) {
        return terminalSets[id].terminals[terminal];
    }
}

/*
 * An asset set is an arbitrary collection of asset addresses. These collections can be reused for both collateral allow
 * lists and loan allow lists.
 */
contract AssetSetCollection {
    struct AssetSet {
        bool exists;
        mapping(address => bool) assets;
    }

    mapping(bytes32 => AssetSet) private assetSets;

    event AssetSetStored(bytes32 indexed id, address[] assets);

    function storeAssetSet(bytes32 id, address[] calldata assets) public {
        require(!assetSets[id].exists);
        for (uint256 i; i < assets.length; i++) {
            assetSets[id].assets[assets[i]] = true;
        }
        emit AssetSetStored(id, assets);
    }

    function isInAssetSet(bytes32 id, address asset) external view returns (bool) {
        return assetSets[id].assets[asset];
    }
}
