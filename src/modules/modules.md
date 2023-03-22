# Modules

Each Module category will have many types implemented and each type will have many instances. Each type is expected to use the protocol-defined struct
for its parameters encoding. Each struct includes the minimum set of data that is necessary to operate an Module and a `parameters` field that contains
arbitrary data for implementation-specific use for the type. Different instances of the same type are distinguished through unique parameter data. 
The structure of the `parameters` field is expected to be defined by the Module type implementation contract and standardized across all instances of that type.

The data represented in a Module parameter instance is static and will not change after an Agreement is deployed.

An implementation contract for a Module represents a Type of that module.
A set of parameters + a type implementation is an instance.


???
why define a struct for each rather than just passing the bytes directly?
you can guarantee parity between different components of an agreement - i.e. loanAsset and loanOracle
^^ forced compatibility can be achieved through arguments in interfaces


Modulus interface defines module
solidity implementation defines type
parameters bytes define an instance
call arguments define a state