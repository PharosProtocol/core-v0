from brownie.test import given, strategy
from brownie import Token, accounts
import pytest
from brownie import accounts


def test_account_balance():
    balance = accounts[0].balance()
    accounts[0].transfer(accounts[1], "10 ether", gas_price=0)

    assert balance - "10 ether" == accounts[0].balance()


@pytest.fixture
def token():
    return accounts[0].deploy(Token, "Test Token", "TST", 18, 1000)


def test_transfer(token):
    token.transfer(accounts[1], 100, {'from': accounts[0]})
    assert token.balanceOf(accounts[0]) == 900


@pytest.fixture(scope="module")
def token(Token):
    return accounts[0].deploy(Token, "Test Token", "TST", 18, 1000)


def test_approval(token, accounts):
    token.approve(accounts[1], 500, {'from': accounts[0]})
    assert token.allowance(accounts[0], accounts[1]) == 500


def test_transfer(token, accounts):
    token.transfer(accounts[1], 100, {'from': accounts[0]})
    assert token.balanceOf(accounts[0]) == 900


# module_isolation is a module scoped fixture. It resets the local chain before and after completion of the module, ensuring a clean environment for this module and that the results of it will not affect subsequent modules.
# fn_isolation is function scoped. It additionally takes a snapshot of the chain before running each test, and reverts to it when the test completes. This allows you to define a common state for each test, reducing repetitive transactions.
@pytest.fixture(scope="module", autouse=True)
def token(Token, accounts):
    t = accounts[0].deploy(Token, "Test Token", "TST", 18, 1000)
    yield t


@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass


# Parametrizing Tests


@pytest.mark.parametrize('amount', [0, 100, 500])
def test_transferFrom_reverts(token, accounts, amount):
    token.approve(accounts[1], amount, {'from': accounts[0]})
    assert token.allowance(accounts[0], accounts[1]) == amount


@given(amount=strategy('uint', max_value=1000))
def test_transferFrom_reverts(token, accounts, amount):
    token.approve(accounts[1], amount, {'from': accounts[0]})
    assert token.allowance(accounts[0], accounts[1]) == amount
