# Modules

The Module system is what enables Modulus to be permissionless and customizable. The entire system can be thought of as a 
large number of small contracts that plug into a common orderbook via standardized and versioned interfaces. The benefits 
of the Module system comes at the cost of complexity and minor additional inefficiency to the system. The module system
also indirectly increases system security by distributing capital and risk across many contracts and implementations.

## Understanding Modules
There are 4 layers to consider when understanding a Module. From highest level to lowest level:
1. Module Category - Defined by which standardized *interface* a module implements  
2. Module Type - Defined by the *solidity implementation* of a module
3. Module Instance - Defined by the *parameter bytes*, which are immutable across the lifetime of the instance
4. Module State - Set and altered by *functions*

Each Module Category may have many Types implemented and each Type may have many Instances which will in turn manage their
own state.
Each Type must adhere to the protocol-defined interface. Implementation specific data can be passed through an arbitrary 
parameter set which is unique to the implementation. Types may implement additional functions beyond the standard interface,
although the other components of the system will be unable to use the additional functionality.
Two Instances of the same type are distinguished only by their `parameters` bytes. Some Types may not need either Instances or State (i.e. Assessors). Some Types may need Instances but not state (i.e. Oracles).

Standard interfaces may also require non-state changing arguments to ensure delivery of the minimum set of valid data to operate
a Module of that Category. ? you can guarantee parity between different components of an agreement - i.e. loanAsset and loanOracle ?

### Module Categories
- Account
- Assessor
- Oracle
- Liquidator
- Position

## Design Invariants
- No module has any special access to Bookkeeper beyond what an EOA has. No module can compel Bookkeeper to move assets.
- No module has any special access to other modules beyond what an EOA has. They cannot compel another module to move assets.
- Bookkeeper can compel Modules to move assets.
- Payments between modules are done by *pushing*(?). No approvals needed.
- Every module Category interface should offer a transfer wrapper that covers all transfer out needs. This allows modules to handle arbitrary asset implementations without the Bookkeeper needing any knowledge of how to handle the asset. Receive functionality should be implemented per module to match out.

#### List of all transfer scenarios
- *Load*: User -> Account, pulls
- *Unload*: Account -> User, pushes
- *Capitalize*: Account -> Position, pushes
- *Exit*: Position -> Accounts, pushes
~~- *Eject*: Position -> User, pushes, liquidator~~
- honorable mention: *transferContract*: give Liquidator module ownership of Position

## Implementing a Module
are modules expected to verify their data?

## Module implementation notes
- All modules should have a non-reverting callback implemented. This allows them to be compatible with other modules
that use non-standard functions.
^^ Arguably the opposite is true. Hard revert on non-implemented functions to indicate incompatibility. But this may
just cause stuck positions as indicator may come too late.


// IDEA
// Tag based compatibility system. Each module implementation could self select tags that represent it. The UI
// users, and other contracts can pull these tags and use them to determine if modules fit together for a healthy
// agreement. This avoids the issue of new modules being default-incompatible with all existing modules, yet it
// allows for intricate compatibility.
// Ex) Assessor:deterministic_cost, Account:assessor_updater, position:imperfect_exit_amount
// Not covered by this design is where a module adds a tag that indicates *incompatibility* with another module bc
// existing modules would not be aware of newly implemented incompatibility tags.
