# Freighter
Freighter plugins define how an asset is moved within the Pharos ecosystem. Both between plugins and users.

Assets location is a state machine with 3 location states: *users*, *ports*, *terminals*

Transfers are executed in the state space of the port or terminal and pushing is preferred. Both of these plugins
are implemented using an MPC design that limits the possible damage of executing arbitrary third party code in
the state space of the plugin. Only the MPCs and assets directly associated with an agreement would be at risk 
of malicious plugin implementations. Users are expected to make responsible choices on which plugins to use.

Transfers between states require informing the sender and receiver of the action, except when one actor is a 
user. Informing the recipient is handled through bookkeeper only delegatecall callbacks.

Abstracting asset control into a plugin is powerful because it allows rapid expansion to new asset types without
redefining existing plugins. For example, if a terminal only supports erc20s it would be possible to implement an
asset with native staking of a token in a way that *only* requires implementation of an Asset contract. 
Port implementations do not need to understand the asset at all and the asset can be converted to a compatible
erc20 before being transferred to the Terminal.

## Design
- It is not safe for the bookkeeper to (delegate) call Freighters bc the bk contains shared state.
- All assets, loan and collateral, are moved to position at agreement time. This is obviously gas intensive and
in many cases wasteful, however it is necessary to maintain appropriate separation of assets by agreement and
strictly limit user risk to the agreements they have explicitly participated in.