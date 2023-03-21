# Assessors
Assessors are standalone contracts that calculate the current cost of a loan using custom logic. Users are able to permissionlessly deploy and use Assessors in Modulus. Assessors should adhere to the standard
shown in IAssessorFactory.sol.

## Use with Pharos
An Assessors can be permissionlessly deployed and used publicly within Modulus. However, in the interest of user security, there are additional steps an Assessor creator will need to take before Modulend will advertise the Assessor (or any components using it).

### Visibility
If a User wants an Assessor, or any component using the Assessor, to appear in the Modulend marketplace for public use
they will need to submit the code for verification on Etherscan. Only Assessors with verified public code will
be visible.

### Verification
In order for an Assessor to be marked as verified in the Modulend marketplace it must first be audited by a trusted third party to ensure that it conforms to standards and it is performing a secure and authentic cost assessment.

## Examples
This directory contains example implementations of Assessors. These examples will be deployed and useable through Modulus.
