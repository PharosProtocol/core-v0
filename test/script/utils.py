from brownie import (accounts, LibBookkeeper, Bookkeeper, SoloAccount,
                     StandardAssessor, UniV3HoldFactory, UniswapV3Oracle, InstantLiquidator, LibUniswapV3, Utils)

from brownie.network import max_fee, priority_fee

from eth_abi import encode, encode_packed, decode

ERC20_ACCOUNT_PARAMS = ['address', 'bytes32']


def main():
    """Run `brownie run utils --interactive` from CLI to enter a well-configured interactive brownie console."""
    deploy()


def deploy():
    max_fee("100 gwei")
    priority_fee("10 gwei")
    LibBookkeeper.deploy({'from': accounts[0]})
    Bookkeeper.deploy({'from': accounts[0]})

    Utils.deploy({'from': accounts[0]})
    LibUniswapV3.deploy({'from': accounts[0]})
    SoloAccount.deploy(Bookkeeper[0].address, {'from': accounts[0]})
    StandardAssessor.deploy({'from': accounts[0]})
    UniV3HoldFactory.deploy(Bookkeeper[0].address, {'from': accounts[0]})
    UniswapV3Oracle.deploy({'from': accounts[0]})
    InstantLiquidator.deploy(Bookkeeper[0].address, {'from': accounts[0]})

def uni_path(token0, fee, token1):
    return encode_packed(['address', 'uint24', 'address'], [token0, fee, token1])

def order_blueprint(publisher, order):
    return (publisher, encode_packed(['bytes1', 'bytes'], [0, order]))
