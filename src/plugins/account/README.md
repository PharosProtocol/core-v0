# Design
- Accounts are MPCs
- Accounts should *not* assume to know all sources of funds. Funds may appear unexpectedly from position profits, token
rebasing, unknown plugin implementations, or other asset-specific behavior.
- there are 2 states of assets in an account, locked and unlocked. assets are unaware if they themselves are locked.
- accounts should be entirely agnostic to the asset implementation. all that accounts do is act as an address to
'hold' assets and keep track of locked amounts. further complexity can be implemented to enhance user capabilities, but
no complexity should be added in regards to specific assets. Asset compatibility is handled by Asset and Terminal
contracts.
- any account can receive and withdraw any asset as long as their is a compatible freighter implementation. Some
accounts, like pooled accounts, may need additional logic to track expected assets.

### Notes
- moving collateral to position vs holding in account
    - moving is far simpler. would take that simplicity and security in exchange for the increased gas costs, however
    there is also the issue of assets that are difficult to move. for example, staked assets.
    - there is a case for identifying 2 states of every asset: deployed and undeployed. all yields are sacrificed when
    deployed, including deployed as collateral.
- potential increase in simplification by removing unnecessary ability to borrow same asset as collateral

ok so keeping assets locked in account ruins invariant of address assets all belonging to user and address balance 
representing user balance

however, some collateral assets may suffer carrying costs when moving or being held elsewhere


example asset types
- dynamic value
- stable value
- rebasing (increase)
- rebasing (decrease)
- fee on transfer
- staked
- 1155
...

^ there are too many to support directly. but if we can abstract things such that supporting a new asset does not require
updating all plugins it will be a win.
is it possible to get to a point where the UI knows "I trust SoloAccount impl at 0x123..." and a new asset impl
is introduced that is very novel without the need to update all plugins and it is safe to share with users?



