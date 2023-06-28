# Example user experience to create markets

## Replication of your favorite large protocol
User navigates to Pharos UI, selects bluechip assets for collateral and borrow whitelists, selects Simple Hold terminal, limits CR to 150%, selects Instant Liquidator, selects interest terms that match existing protocol, etc. Connects this market definition to an account with assets and submits the order to Pharos orderbook.

## Novel market
User navigates to Pharos UI, selects Doodles NFT collection as whitelisted collateral, asks to borrow Eth, sets liquidation to be forfeiture of NFT. Instead of conventional interest, they deploy a small contract (~50 lines Sol) that defines they will pay 10% of Doodle floor price value at loan closure.

# Security 

- TODO - **Existing Vulnerability??** - contracts implementing receive functions could be malicious. Reentrancy ofc, which
has been considered a bit (need to verify use of CEI flow) but also griefing. a borrower could borrow via a smart 
contract which reverts on fund receipt thus locking lender funds in the contracts. Might be alleviated by using verified
account contracts?
https://fravoll.github.io/solidity-patterns/pull_over_push.html

- Question: when is it ok to use types smaller than uint256? Such as int256 or uint128? also, when is it preferred?

- what if a module or position is also the borrower/lender?
