
import pytest


from brownie.network import max_fee, priority_fee

from brownie import (LibBookkeeper, Bookkeeper, DoubleSidedAccount,
                     StandardAssessor, UniV3HoldFactory, UniswapV3Oracle, InstantLiquidator, LibUniswapV3, Utils)




@pytest.fixture(scope="module", autouse=True)
def fees(accounts):
    max_fee("100 gwei")
    priority_fee("2 gwei")

@pytest.fixture(scope="module")
def bookkeeper(accounts):
    LibBookkeeper.deploy({'from': accounts[0]})
    yield Bookkeeper.deploy({'from': accounts[0]})

@pytest.fixture(scope="module")
def modules(accounts, bookkeeper):
    Utils.deploy({'from': accounts[0]})
    LibUniswapV3.deploy({'from': accounts[0]})
    DoubleSidedAccount.deploy(bookkeeper.address, {'from': accounts[0]})
    StandardAssessor.deploy({'from': accounts[0]})
    UniV3HoldFactory.deploy(bookkeeper.address, {'from': accounts[0]})
    UniswapV3Oracle.deploy({'from': accounts[0]})
    InstantLiquidator.deploy(bookkeeper.address, {'from': accounts[0]})


@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass


def test_deploy(accounts, bookkeeper, modules):
    print('hi')
