// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IFreighter} from "src/interfaces/IFreighter.sol";

/// @notice Literally all of this ugliness to create a pseudo library to enable inheritance. is sol a real language?
abstract contract Freighter is IFreighter {
    address public immutable FREIGHTER_ADDR;

    modifier delegateExecution() {
        require(address(this) != FREIGHTER_ADDR, "Cannot call freighter directly");
        _;
    }

    constructor() {
        FREIGHTER_ADDR = address(this);
    }
}
