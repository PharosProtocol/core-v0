# Pharos
Pharos is a permisionless lending protocol on Ethereum that allows lenders and borrowers to place fully customizable lending orders for any asset.
Pharos uses a modular architecture to create lending markets. Lenders and borrowers create accounts and either fill existing orders or create ones. 
An account can hold any ERC-20 and place multiple, fully customizable, orders. Pharos uses EIP-712 to create a gas efficient order book. 
Accounts can also deploy assets into other protocols until an order is filled. 
Once an order is filled, a loan can be either over or under-collateralized. Under-collateralized loans are custodied by Pharos and borrowers can only perform actions whitelisted by the lender. 
In the example below, Borrower-A has an under-collateralized loan (leveraged) with Lender-A and can only use the loan in Uniswap. Borrower-A also has an over-collateralized loan with with Lender-B and has full control over the loaned assets.
