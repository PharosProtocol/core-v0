# Testing
Testing is primarily performed using Forge. For lots of reasons but especially bc I do not want to spend the next
two days fighting ts compilers and package managers.

# Invariant Testing

# Fuzz Testing

# Unit Testing

# End-to-End Testing


# Notes on testing design

## Writing tests
- Never make assertions in the `setUp()` function (https://github.com/foundry-rs/foundry/issues/1291)
- Using testFail is considered an anti-pattern since it does not tell us anything about why
- Use unique string params in asserts?

## Organization
- For `MyContract.sol`, the test file should be `MyContract.t.sol`
- One test contract per contract-under-test
- Test contracts/functions should be written in the same order as the original functions in the contract-under-test
- All unit tests that test the same function should live serially in the test file

## Naming
- test_Description for standard tests.
- testFuzz_Description for fuzz tests.
- test_Revert[If|When]_Condition for tests expecting a revert.
- testFork_Description for tests that fork from a network.
- testForkFuzz_Revert[If|When]_Condition for a fuzz test that forks and expects a revert

# References
- https://ethereum.github.io/yellowpaper/paper.pdf
- https://book.getfoundry.sh/tutorials/best-practices
- https://book.getfoundry.sh/forge/writing-tests
- https://book.getfoundry.sh/forge/invariant-testing

