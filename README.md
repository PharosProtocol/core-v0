# Pharos
Pharos is *lending market factory* that enables users to trivially create any possible lending markets using any terms and any assets.

The protocol is designed with a modular architecture that allows for permissionless expansion by third party developers and protocols. Users can deploy novel modules that enforce unique loan parameters. Deployed modules can be tweaked and used by all users. A loan agreement is composed of an arbitrary set of modules and loan parameters, which are utilized and enforced by the Pharos Bookkeeper contract. 

Pharos uses EIP-712 to create a gas efficient order book. New orders are encoded and signed with a user's wallet. This signature proves signer is authentic without the need to publish and store the order on chain. Storage of signed orders is left to the UI implementation or the user themselves.

Undercollateralized Loans can be deployed directly into other protocols. Loans are jointly custodied by the user, Pharos, and the deployment module. Borrowers can only perform actions whitelisted by the lender.


## Math Notes
Cumulative math system allows for tracking historical time weighted averages in minimal storage. The most popular example is Uniswap pool TWAP - used to track time weighted price.
Pharos can implement this system to track historical account utilization, loan cost over time, and more.