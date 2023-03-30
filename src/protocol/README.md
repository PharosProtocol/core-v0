# Modulus
Modulus is an open source protocol that enables peer-to-peer lending of assets via independent and customizable loan terms. The protocol allows anyone to define a novel set of loan terms, which includes a list of approved uses of borrowed funds. Approved use cases range from simply holding a volatile asset to entering an advanced on-chain position. Lenders and borrowers who find an existing set of terms agreeable can opt to supply or borrow funds directly with Modulus facilitating the secure management of funds.

Loan terms can be customized for risk tolerance by adjusting collateralization, liquidation mechanisms, approved uses of borrowed capital, and more. Each set of terms is unique and does not impact existing loans.

## Architecture Design
https://www.figma.com/file/0rnDtlA49rKndhsagzxplD/MODULEND-Architecture?node-id=0%3A1&t=b1vk0xE08f6pKOCr-0


## Examples

A) Replicating Balaji bet that BTC will go to $1M in 2023
    To recreate a bet that an asset will be at a given price at a given timestamp a user would set up a loan such that
    the non-speculative asset is the collateral and has a fixed value the matches the end value price, the speculative
    asset is the loan asset and has a value of the bet price until the bet end time is reached when it should switch
    to a value of 0. The min collateral ratio should be set to 1.0 and early exits should be disabled. With this
    configuration anyone can trigger a 'liquidation' at the end ...............