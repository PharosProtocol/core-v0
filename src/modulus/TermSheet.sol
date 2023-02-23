// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import {IOracle} from "src/modulus/Oracle.sol";

/**
 * A term Sheet represents the terms between Lenders and Borrowers. Term sheets are entirely agnostic and unaware of
 * supply accounts, borrow accounts, and Terminals, which enables unrestricted reuseability. Term sheets define the
 * relationship between the Savings account, borrowers, liquidators, and terminals.
 * If an oracle is not defined for an asset the asset cannot be used with these Terms. Asset restrictions are set in
 * Offer and Request Accounts.
 *
 * - Asset must be an ERC20.
 * - Do not deploy collaterals.
 */
struct TermSheet {
    Terms terms;
    mapping(address => OracleCall) oracles;
}

struct Terms {
    /* Operational Parameters */
    uint256 maxCollateralizationRatio;
    uint256 liquidatorReward;
    /* Cost Parameters */
    uint256 maxDuration; // seconds
    uint256 interestRateRatio; // per second
    uint256 loanFee;
    uint256 profitShareRatio;
}

// How to value an asset.
struct OracleCall {
    address oracle;
    bytes data;
}

contract RequestAccountRegistry {
    mapping(bytes32 => TermSheet) public sheets;

    event TermSheetCreated(bytes32);

    // NOTE: Passing in individual pieces overfills stacks limit
    //          What will happen to stack if these arrays are long?
    function createTermSheet(
        bytes32 id,
        Terms calldata terms,
        address[] calldata assets,
        address[] calldata oracles,
        bytes[] calldata datas
    ) public {
        TermSheet storage sheet = sheets[id];
        require(sheet.terms.maxCollateralizationRatio > 0);
        require(terms.maxCollateralizationRatio > 0);
        sheet.terms = terms;
        for (uint256 i; i < assets.length; i++) {
            sheet.oracles[assets[i]] = OracleCall({oracle: oracles[i], data: datas[i]});
        }
    }

    function getValue(bytes32 termSheet, address asset) public view returns (uint256) {
        // OracleCall oracleCall = sheets[termSheet].oracles[asset];
        return IOracle(sheets[termSheet].oracles[asset].oracle).getValue(sheets[termSheet].oracles[asset].data);
    }
}

