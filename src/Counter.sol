// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract Counter is Ownable {
    uint256 public number;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        number++;
    }

    function ownerIncrement() public onlyOwner {
        number+=2;
    }
}
