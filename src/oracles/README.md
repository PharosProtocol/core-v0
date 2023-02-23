# Design Questions
Should we use data arguments or not?
- no?
    - more transparency for users
    - no need to 'verify' every oracle+data combination
    - less UI custimization needed (i..e. much simpler deployment of new Term Sheets)
- yes?
    - *far* fewer oracles necessary to cover expected use cases

# Oracles
Oracles are standalone contracts that report the value of an asset using custom logic. Users are able to permissionlessly deploy and use Oracles in Modulus. Oracles should adhere to the standard
shown in IOracle.sol.

## Use with Modulend
An Oracle can be permissionlessly deployed and used publicly within Modulus. However, in the interest of user security, there are additional steps an Oracle creator will need to take before Modulend will advertise the Oracle (or any Term Sheets using it).

### Visibility
If a User wants an Oracle, or any Term Sheet using the Oracle, to appear in the Modulend marketplace for public use
they will need to submit the code for verification on Etherscan. Only Oracles with verified public code will
be visible.

### Verification
In order for an Oracle to be marked as verified in the Modulend marketplace it must first be audited by a trusted third party to ensure that it conforms to standards and it is performing a secure and authentic valuation.

## Examples
This directory contains example implementations of Oracles. These examples will be deployed and useable through Modulus.