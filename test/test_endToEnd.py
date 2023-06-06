
import pytest

from .script import utils

from brownie.network import max_fee, priority_fee

from eth_abi import encode, encode_packed, decode
from web3 import Web3

from brownie_tokens import MintableForkToken

import .script.utils as utils

# from brownie import (LibBookkeeper, Bookkeeper, SoloAccount,
#                      StandardAssessor, UniV3HoldFactory, UniswapV3Oracle, InstantLiquidator, LibUniswapV3, Utils)

RATIO_FACTOR = 1e18
WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"


@pytest.fixture(scope="module", autouse=True)
def fees(accounts):
    max_fee("100 gwei")
    priority_fee("2 gwei")


@pytest.fixture(scope="module", autouse=True)
def deploy(accounts):
    Utilsdeploy()


@pytest.fixture(autouse=True)
def isolation(fn_isolation):
    pass


def test_agree(accounts):
    bk = Bookkeeper[0]
    a = SoloAccount[0]

    usdc = MintableForkToken.from_explorer(
        "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")
    weth = MintableForkToken.from_explorer(
        "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2")

    usdc_asset = (20, "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", 0, '')
    weth_asset = (20, "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 0, '')

    lender = accounts[1]
    borrower = accounts[2]

    # usdc._mint_for_testing(lender, amount)
    weth._mint_for_testing(lender, 11e18)
    usdc._mint_for_testing(borrower, 5_000e6)
    weth._mint_for_testing(borrower, 3e18)

    lenderAccountParams = encode(['address', 'bytes32'], [lender, b'0'])
    borrowerAccountParams = encode(['address', 'bytes32'], [borrower, b'0'])

    usdc.approve(a, 10e18, {'from': lender})
    a.load(weth_asset, 10e18, lenderAccountParams, {'from': lender})
    usdc.approve(a, 5_000e6, {'from': borrower})
    a.load(usdc_asset, 5_000e6, borrowerAccountParams, {'from': borrower})

    accountMod = (a.address, lenderAccountParams)
    assessorMod = (StandardAssessor[0].address, encode(['uint256', 'uint256', 'uint256'],
                                                       [RATIO_FACTOR / 100, RATIO_FACTOR / 1000000, RATIO_FACTOR / 20]))
    liquidatorMod = (InstantLiquidator[0].address, encode(
        ['uint256', 'uint256', 'uint256'], [0, 0, 0]))
    minLoanAmounts = [1e18]
    loanAssets = [weth_asset]
    collAssets = [usdc_asset]
    takers = []
    maxDuration =
    loanOracles = [(UniswapV3Oracle[0].address, encode(['bytes', 'bytes', 'uint256', 'uint32'],
                                                       [uni_path(USDC, 500, WETH),
                                                       uni_path(
                                                           WETH, 500, USDC),
                                                       RATIO_FACTOR/1000,
                                                       300]))]
    collOracles = [(StaticUsdcPriceOracle[0].address,
                    encode(['uint256'], [1e6]))]
    factories = [UniV3HoldFactory[0].address]

    offer = (minLoanAmounts, loanAssets, collAssets, takers, 60*60*24*7, RATIO_FACTOR/5,
             accountMod, assessorMod, liquidatorMod, loanOracles, collOracles, factories, true, (0, ""))

    offerBlueprint = (lender, bk.packDataField
