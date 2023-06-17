// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "src/Bookkeeper.sol";

// to run:
// forge script script/sign.s.sol:SignScript

contract SignScript is Script {
    function setUp() public {}

    function run() public {
        uint256 privateKey = uint256(0x0);
        bytes32 rawHash = 0x0;
        // Utils utils = new Utils();
        // LibBookkeeper libBookkeeper = new LibBookkeeper();

        Bookkeeper bookkeeper = new Bookkeeper();

        bytes32 fullHash = bookkeeper.getTypedDataHash(rawHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, fullHash);
        console.log("signature: ");
        console.logBytes(abi.encodePacked(r, s, v));
    }
}
