# Pharos
Pharos is a DeFi primitive that allows any user to create leveraged lending markets between any assets under any terms.

The protocol enables lenders and borrowers to permissionlessly coordinate peer-to-peer loans. Mutually agreed loans can access customizable risk management and cost options via third party plugins. The on-chain nature of the ecosystem ensures transparent and trustless management of loans, including the use of on-chain positions with leverage.

Pharos uses a plugins infrastructure where lenders and borrowers mix and match plugins to create unique lending markets. In this way, Pharos does not attempt to predict all possible markets that DeFi users need. Instead they are free to create there own markets, with near limitless customizability.

# Setup

1. Install forge
2. `forge install`
3. The pool init code hash in lib/v3-periphery/contracts/libraries/PoolAddress.sol needs to be updated to match the hash used to deploy existing uniswap v3 pools.
0xa598dd2fba360510c5a8f02f44423a4468e902df5857dbce3ca162a43a3a31ff -> 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54
4. `forge test --fork-url <YOUR_RPC_URL>`

