// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {Asset} from "src/LibUtil.sol";

interface ITerminal {
    // Verify that implementation specific parameters are valid with the agreement fields.
    // function isValidAgreement(Agreement memory agreement) external returns (address addr); // TODO implement here and other modules
    function createPosition()
        external
        returns (address);
}
