# Modulus
Modulus is an open source protocol that enables peer-to-peer lending of assets via independent and customizable loan terms. The protocol allows anyone to define a novel set of loan terms, which includes a list of approved uses of borrowed funds. Approved use cases range from simply holding a volatile asset to entering an advanced on-chain position. Lenders and borrowers who find an existing set of terms agreeable can opt to supply or borrow funds directly with Modulus facilitating the secure management of funds.

Loan terms can be customized for risk tolerance by adjusting collateralization, liquidation mechanisms, approved uses of borrowed capital, and more. Each set of terms is unique and does not impact existing loans.

## Architecture Design
https://www.figma.com/file/0rnDtlA49rKndhsagzxplD/MODULEND-Architecture?node-id=0%3A1&t=b1vk0xE08f6pKOCr-0


## Example Markets


# Security 

- TODO - **Existing Vulnerability** - contracts implementing receive functions could be malicious. Reentrancy ofc, which
has been considered a bit (need to verify use of CEI flow) but also griefing. a borrower could borrow via a smart 
contract which reverts on fund receipt thus locking lender funds in the contracts. Might be alleviated by using verified
account contracts?
https://fravoll.github.io/solidity-patterns/pull_over_push.html