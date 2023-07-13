# Testing
Testing code is very much still a WIP. The most comprehensive test is the end to end test.
Each module implemented should also feature a single unit test and an invariant test (partially implemented).

## Forge
The majority of tests are written using Foundry. Anvil is used for local fork node running. 


## Test Types
### Unit Testing
Unit tests consist of pre-determined input and an expected output. If the output does not match expectations or if execution reverts unexpectedly the test fails.
### Fuzz Testing
Fuzz tests consists of semi-random inputs and unknown outputs. In some cases expected output may be able to be determined at runtime. If execution reverts unexpectedly (or if output does not match expectations when available) the test fails. Avoid writing wrappers for fuzz testing to keep things simple.
### Invariant Testing
Invariant tests consist of semi-random inputs and random function calls. Invariant checks should hold true against any random activity. Invariant testing often requires the contract to be wrapped in a *Handler* so that it is possible to verify the invariant checks are holding to expectations. 
### End-to-End Testing


## Forge tips
- To see real time RPC logs use `RUST_LOG=forge=trace,foundry_evm=trace,ethers=trace forge test`
- To avoid extremely long run times of invariant tests use a seed so calls can be cached.
- https://book.getfoundry.sh/tutorials/best-practices

## Notes on testing design

### Writing tests
- Never make assertions in the `setUp()` function (https://github.com/foundry-rs/foundry/issues/1291)
- Using testFail is considered an anti-pattern since it does not tell us anything about why

### Organization
- For `MyContract.sol`, the test file should be `MyContract.t.sol`
- One test contract per contract-under-test
- Test contracts/functions should be written in the same order as the original functions in the contract-under-test
- All unit tests that test the same function should live serially in the test file

### Naming
- test_Description for unit tests.
- testFuzz_Description for fuzz tests.
- invariant_Description for invariant checks.
- ~~test_Revert[If|When]_Condition for tests expecting a revert.~~
- ~~testFork_Description for tests that fork from a network.~~
- ~~testForkFuzz_Revert[If|When]_Condition for a fuzz test that forks and expects a revert~~


# References
- https://ethereum.github.io/yellowpaper/paper.pdf
- https://book.getfoundry.sh/tutorials/best-practices
- https://book.getfoundry.sh/forge/writing-tests
- https://book.getfoundry.sh/forge/invariant-testing
- https://hackmd.io/@xx8i-6tERA6IXXxVfWGABg/BkDI2dTsi
- https://github.com/dabit3/foundry-workshop

- https://eth-brownie.readthedocs.io/
- https://github.com/curvefi/brownie-tutorial/
    - Noted that ERC20 token package does not seem to work with anvil (or at all?). This is likely due to the fact that it attempts transfers from existing whale wallets. Anvil does not allow txn from these wallets without the keys to sign them. Might be able to use brownie bypass for accounts if i knew the addresses.


`anvil --fork-url https://eth-mainnet.g.alchemy.com/v2/XXXXXXXXXXXXXXXXX --fork-block-number 17186176`
`brownie test --network anvil`
`brownie run utils --network anvil --interactive`


