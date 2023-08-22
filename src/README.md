# Design
Pharos architecture consists of two sources of code: one bookkeeper and various plugins.

## Bookkeeper
There is only a single instance of the bookkeeper. It is responsible for coordinating the various plugins and ensuring that loan agreements are handled trustlessly between both parties. The bookkeeper is immutable and
can be trusted by modules (after reviewing verified source code ofc).

## Plugins
Each plugin is a standalone contract meant to perform one duty of loan management. They can be permissionlessly
deployed by anyone and therefore cannot be trusted. See more in `src/modules/README.md`. This permissionless use of solidity code by the protocol is a large part of what makes Pharos novel and extremely customizable.

## Design
- Many plugin categories would make more sense being implemented as a library, but solidity libraries do not offer
inheritance that is necessary to set shared modifiers for all plugin implementations or other universal logic.

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
- It is possible that a module cannot handle an agreement and locks up. It is expected that the user / UI does
not create an invalid offer / agreement.

- all *standard* user-facing calls live inside of the bookkeeper
- ^^ => all *standard* external plugin calls should be bookkeeper only 
- non-standard calls may be implemented in certain plugin types and directly accessible to external users

## Outstanding Thoughts and Questions

- contracts implementing receive functions could be malicious. Reentrancy ofc, but also griefing. a borrower could borrow via a smart 
contract which reverts on fund receipt thus locking lender funds in the contracts. This puts the onus on 
the UI/user to not enter agreements with bad actor plugins. However, this creates friction with adoption of new plugins, particularly accounts, which conceptually the opposing party should be indifferent towards.

- Question: when is it ok to use types smaller than uint256? Such as int256 or uint128? also, when is it preferred?

- what if a module or position is also the borrower/lender?

- What are Pharos invariants?
https://www.nascent.xyz/idea/youre-writing-require-statements-wrong

- What is the cost of putting non-reentrant on all external calls? This is what I have done to guard against 
reentrancy, but it is not clear what modern costs are using OZ in sol 0.8+ with refunding mechanisms in place.

## Temporary Security Limitations
In order to ensure a more secure launch, Pharos will limit some early functionality. This provides us more time to
test, audit, and improve some of the elements that are most novel.

### v0 (testnet & L2)
- Loan size limits
- Permissionless use of 3rd party modules will be disabled.
- Direct interaction with Position protocol wrappers will not be implemented.
