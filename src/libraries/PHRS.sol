// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PharosToken is ERC20 {
    constructor(
        address[] memory initialHolders, 
        uint256[] memory initialBalances
    ) ERC20("pharos", "PHRS") {
        for (uint i = 0; i < initialHolders.length; i++) {
            _mint(initialHolders[i], initialBalances[i]); 
        }
    }
}
