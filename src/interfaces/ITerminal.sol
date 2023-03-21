// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.15;

import {TerminalCalldata} from "src/libraries/LibTerminal.sol";

interface ITerminal {
    function createPosition(TerminalCalldata memory terminalCalldata) external returns (address addr);
}
