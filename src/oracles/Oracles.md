# Oracles
Oracles are independent contracts that report the value of an asset using custom logic. Users are able to permissionlessly deploy and use Oracles in Modulus. Oracles should adhere to the standard
shown in IOracle.sol.

## Use with Modulend
Any Oracle created and used permissionlessly within Modulus. However, in the interest of user security, there are
additional steps an Oracle creator will need to take before Modulend will advertise the Oracle.

### Visibility
If a User wants an Oracle, or any Term Sheet using the Oracle, to appear in the Modulend UI for public use
they will need to submit the code for verification on Etherscan. Only Oracles with verified public code will
be visible.

### Verification
In order for an Oracle to be marked as verified in the Modulend UI it must first be audited by a trusted third party
to ensure that it conforms to standards and it is performing a secure and authentic valuation.
