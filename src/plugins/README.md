# Plugins

The Plugin system is what enables Modulus to be permissionless and customizable. The entire system can be thought of as a 
large number of small contracts that plug into a common orderbook via standardized and versioned interfaces. The benefits 
of the Plugin system comes at the cost of complexity and minor additional inefficiency to the system. The plugin system
also indirectly increases system security by distributing capital and risk across many contracts and implementations.

## Understanding Plugins
There are 4 layers to consider when understanding a Plugin. From highest level to lowest level:
1. Plugin Category - Defined by which standardized *interface* a plugin implements  
2. Plugin Type - Defined by the *solidity implementation* of a plugin
3. Plugin Instance - Defined by the *parameter bytes*, which are immutable across the lifetime of the instance
4. Plugin State - Set and altered by *functions*

Each Plugin Category may have many Types implemented and each Type may have many Instances which will in turn manage their
own state.
Each Type must adhere to the protocol-defined interface. Implementation specific data can be passed through an arbitrary 
parameter set which is unique to the implementation. Types may implement additional functions beyond the standard interface,
although the other components of the system will be unable to use the additional functionality.
Two Instances of the same type are distinguished only by their `parameters` bytes. Some Types may not need either Instances or State (i.e. Assessors). Some Types may need Instances but not state (i.e. Oracles).

Standard interfaces may also require non-state changing arguments to ensure delivery of the minimum set of valid data to operate
a Plugin of that Category. ? you can guarantee parity between different components of an agreement - i.e. loanAsset and loanOracle ?

### Plugin Categories
- Account
- Assessor
- Oracle
- Liquidator
- Position

### Plugin Parameters
A plugin instance is defined by an address of a deployed Type implementation and a set of parameters. The parameters
are encoded into the Order and Agreement as bytes and decoded inside of the plugin - only the plugin itself knows
how to decode the parameters and can act on the encoded information. If data is needed externally it must be made
accessible through callable functions. Every plugin Type will define its own parameter configuration inside of its
contract. Parameter definitions are optional.

## Design Invariants
- No plugin has any special access to Bookkeeper beyond what an EOA has. No plugin can compel Bookkeeper to move assets.
- No plugin has any special access to other plugins beyond what an EOA has. They cannot compel another plugin to move assets.
- Bookkeeper can compel Plugins to move assets.
- Payments between plugins are done by *pushing*(?). No approvals needed.
- Every plugin Category interface should offer a transfer wrapper that covers all transfer out needs. This allows plugins to handle arbitrary asset implementations without the Bookkeeper needing any knowledge of how to handle the asset. Receive functionality should be implemented per plugin to match out.

#### List of all transfer scenarios
- *Load*: User -> Account, pulls
- *Unload*: Account -> User, pushes
- *Capitalize*: Account -> Position, pushes
- *Exit*: Position -> Accounts, pushes
~~- *Eject*: Position -> User, pushes, liquidator~~
- honorable mention: *transferContract*: give Liquidator plugin ownership of Position

## Implementing a Plugin
are plugins expected to verify their data?

## Plugin implementation notes
- All plugins should have a non-reverting callback implemented. This allows them to be compatible with other plugins
that use non-standard functions.
^^ Arguably the opposite is true. Hard revert on non-implemented functions to indicate incompatibility. But this may
just cause stuck positions as indicator may come too late.


// IDEA
// Tag based compatibility system. Each plugin implementation could self select tags that represent it. The UI
// users, and other contracts can pull these tags and use them to determine if plugins fit together for a healthy
// agreement. This avoids the issue of new plugins being default-incompatible with all existing plugins, yet it
// allows for intricate compatibility.
// Ex) Assessor:deterministic_cost, Account:assessor_updater, position:imperfect_exit_amount
// Not covered by this design is where a plugin adds a tag that indicates *incompatibility* with another plugin bc
// existing plugins would not be aware of newly implemented incompatibility tags.

## Factories and Clones

### Gas
- ERC20 transfer (push) has 2 storage updates, transferFrom has at most 3. thus locking acct vs pushing assets to
    position at position creation time saves ~1 storage update of gas at significant complexity cost/risk.