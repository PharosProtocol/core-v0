// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;



struct Valuator {
    address asset;
    bytes32 valuatorType;
    bytes32 data;
}

struct CurveValuator {
    Valuator valuator;
    address poolAddress;
    int tokenIndex;
}

/**
abstract contract ValuatorProcessor {
    // bytes32 id; // redundant, used to access valuator.
    address asset;
    uint32 valuatorType

    constructor(address calldata asset) {
        asset = asset;
    }

    // Function that returns value of asset in USDC.
    function value() public virtual returns (uint256);
}

abstract contract FunctionCallValuator is Valuator {
    address contractAddress;
    bytes callData;

    constructor(address calldata asset, bytes256 calldata interfaceAsset) Valuator(asset) {
        
    }

    function value() public returns (uint256) {
        return contractAddress.staticcall(callData);
    }
}

abstract contract CurveValuator is Valuator {
    address poolAddress;
    int tokenIndex;

    constructor(address calldata asset, bytes256 calldata interfaceAsset) Valuator(asset) {
        
    }

    function value() public returns (uint256) {}
}

abstract contract UniswapValuator is Valuator {
    address poolAddress;
    int tokenIndex;

    constructor(address calldata asset, bytes256 calldata interfaceAsset) Valuator(asset) {
        
    }

    function value() public returns (uint256) {}
}
*/

library ValuatorUtils {
    function value(Valuator valuator) public returns (uint256) {
        if (valuator.valuatorType == CURVE_VALUATOR_TYPE_ID) {
            return curveValue(valuator);
        }
        return 0;
    }

    function curveValue(CurveValuator valuator) public returns (uint256) {

    }
}