# Terminals
Terminals are standalone contracts that are used to create and enter positions with borrowed capital. They are approximately a wrapper around EVM protocols and capital use cases. Terminals can permissionlessly deployed as independent contracts using a common interface standard defined within Modulus. Any user can deploy a Terminal and interact with it through Modulus.

## Use with Pharos
A Terminal can be permissionlessly deployed and used publicly within Modulus. However, in the interest of user security, there are additional steps a Terminal creator will need to take before Modulus will advertise the Terminal (or any components using it).

### Visibility
If a User wants a Terminal, or any component using the terminal, to appear in the Modulend marketplace, they will need to submit the code for verification on Etherscan. Only Terminals with verified public code will be visible.

### Verification
In order for a Terminal to be marked as verified in the Modulend marketplace it must first be audited by a trusted third party to ensure that it conforms to standards and its operation is secure and authentic.

## Examples
This directory contains example implementations of Terminals. These examples will be deployed and useable through Modulus.