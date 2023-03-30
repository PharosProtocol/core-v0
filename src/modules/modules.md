# Modules

The Module system is what enables Modulus to be permisionless and customizable. The entire system can be thought of as a 
large number of small contracts that plug into a common orderbook via standardized and versioned interfaces. The benefits 
of the Module system comes at the cost of complexity and minor additional inefficiency to the system. The module system
also indirectly increases system security by distributing capital and risk across many contracts and implementations.

## Understanding Modules
There are 4 layers to consider when understanding a Module. From highest level to lowest level:
1. Module Category - Defined by which standardized *interface* a module implements  
2. Module Type - Defined by the *solidity implementation* of a module
3. Module Instance - Defined by the *parameter bytes*, which are immutable across the lifetime of the instance
4. Module State - Set and altered by Type *functions*

Each Module Category may have many Types implemented and each Type may have many Instances which will in turn manage their
own state.
Each Type must adhere to the protocol-defined interface. Implementation specific data can be passed through an arbitrary 
parameter set which is unique to the implementation. Types may implement additional functions beyond the standard interface,
although the other components of the system will be unable to use the additional functionality.
Two Instances of the same type are distinguished only by their `parameters` bytes. Some Types may not need either Instances or State (i.e. Assessors). Some Types may need Instances but not state (i.e. Oracles).

Standard interfaces may also require non-state changing arguments to ensure delivery of the minimum set of valid data to operate
a Module of that Category. ? you can guarantee parity between different components of an agreement - i.e. loanAsset and loanOracle ?

## Design Invariants
No module has any special access to Modulus beyond what an EOA has. They cannot compel Modulus to move assets.
No module has any special access to other Modules beyond what an EOA has. They cannot compel another module to move assets.
Modulus can compel Modules to move assets.

## Implementing a Module
are modules expected to verify their data?