# Example user experience to create markets

## Replication of your favorite large protocol
User navigates to Pharos UI, selects bluechip assets for collateral and borrow whitelists, selects Simple Hold terminal, limits CR to 150%, selects Instant Liquidator, selects interest terms that match existing protocol, etc. Connects this market definition to an account with assets and submits the order to Pharos orderbook.

## Novel market
User navigates to Pharos UI, selects Doodles NFT collection as whitelisted collateral, asks to borrow Eth, sets liquidation to be forfeiture of NFT. Instead of conventional interest, they deploy a small contract (~50 lines Sol) that defines they will pay 10% of Doodle floor price value at loan closure.

# Security 

## Security in Design
- The bookkeeper is considered trusted by plugins and all agreements.
- The bookkeeper does not trust any plugins.
- An agreement *does* trust plugins, as they were manually mutually selected. Poor module choices may lead to loss
of funds for the two parties involved in the agreement. But **only** those two parties.
- Users who have not explicitly agreed to use a module do not trust that module and cannot have funds at risk
regardless of implementation.
- Positions trust their admin. Which is bookkeeper by default and then borrower/liquidator after close.
- Plugins must trust the other plugins that they are in an agreement with, but none of those interactions should
entrust safety of any assets outside of the agreement to depend on safe implementation of the other plugins.

## Outstanding Thoughts and Questions

- TODO - **Existing Vulnerability??** - contracts implementing receive functions could be malicious. Reentrancy ofc, which
has been considered a bit (need to verify use of CEI flow) but also griefing. a borrower could borrow via a smart 
contract which reverts on fund receipt thus locking lender funds in the contracts. Might be alleviated by using verified
account contracts?
https://fravoll.github.io/solidity-patterns/pull_over_push.html

- Question: when is it ok to use types smaller than uint256? Such as int256 or uint128? also, when is it preferred?

- what if a module or position is also the borrower/lender?

- What are Pharos invariants?
https://www.nascent.xyz/idea/youre-writing-require-statements-wrong

- What is the cost of putting non-reentrant on all external calls?

## Temporary Security Limitations
In order to ensure a more secure launch, Pharos will limit some early functionality. This provides us more time to
test, audit, and improve some of the elements that are most novel.

- Testnet / L2 testing will have agreement size limitations.
- Permissionless use of 3rd party modules will be disabled.
- Direct interaction with Position protocol wrappers will not be implemented.

### Core: 

### Entity-Centric

^^ What are the gas costs are implementing explicit checks? For inputs and invariants. 


## Usage Notes
- It is possible that a module cannot handle an agreement and locks up. It is expected that the user / UI does
not create an invalid offer / agreement.