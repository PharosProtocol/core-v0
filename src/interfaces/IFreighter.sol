// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Asset, AssetState, PluginRef} from "src/libraries/LibUtils.sol";

// A freighter represents a state machine with 3 states: external, port, terminal. At each of these states the asset
// being managed should always be in only 1 form. The forms may be different at different states.

interface IFreighter {
    // NOTE is it possible to implement system in a way that only checking of self balance is used?
    // If the compiler’s EVM target is Byzantium or newer (default) the opcode STATICCALL is used when view functions are called, which enforces the state to stay unmodified as part of the EVM execution. For library view functions DELEGATECALL is used, because there is no combined DELEGATECALL and STATICCALL. This means library view functions do not have run-time checks that prevent state modifications. This should not impact security negatively because library code is usually known at compile-time and the static checker performs compile-time checks.
    /// @dev balance should not be assumed to be static. It could change unexpectedly and should be recalculated.
    // Cannot enforce function is view at runtime.
    function balance(
        Asset calldata asset,
        AssetState calldata state,
        bytes calldata parameters
    ) external returns (uint256);

    // NOTE is it possible to impl system such that pulling only happens into ports and never terminals?
    //      this would notably reduce the number of possible transition types.
    function pull(
        address from,
        Asset calldata asset,
        uint256 amount,
        AssetState calldata toState,
        bytes calldata parameters
    ) external payable;

    function push(
        address to,
        Asset calldata asset,
        uint256 amount,
        AssetState calldata fromState,
        bytes calldata parameters
    ) external;

    function processReceipt(
        Asset calldata asset,
        uint256 amount,
        AssetState calldata fromState,
        AssetState calldata toState,
        bytes parameters
    ) external;
}
