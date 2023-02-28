// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * An account holds Lender or Borrower capital that can be deployed through Offers or Requests. A user can have only
 * one Lender Account and one Borrower Account. Each Account may be used by many Offers/Requests.
 * Can accept any erc20 asset, though it may not be useable.
 */
abstract contract Accounts {
    mapping(address => mapping(address => uint256)) private accounts; // user address => asset addreess => amount

    function addAssets(address[] calldata assets, uint256[] calldata amounts) public virtual;

    function _addAssets(address[] calldata assets, uint256[] calldata amounts) internal {
        for (uint256 i; i < assets.length; i++) {
            accounts[msg.sender][assets[i]] += amounts[i];
            require(IERC20(assets[i]).transferFrom(msg.sender, address(this), amounts[i]));
        }
    }

    function removeAssets(address[] calldata assets, uint256[] calldata amounts) public virtual;

    function _removeAssets(address[] calldata assets, uint256[] calldata amounts) internal {
        for (uint256 i; i < assets.length; i++) {
            accounts[msg.sender][assets[i]] -= amounts[i]; // overflow protectins verifies balance
            require(IERC20(assets[i]).transfer(msg.sender, amounts[i]));
        }
    }

    function getBalance(address account, address asset) public view returns (uint256) {
        return accounts[account][asset];
    }
}

contract LenderAccounts is Accounts {
    event LenderAssetsAdded(address indexed lender, address[] asset, uint256[] amount);
    event LenderAssetsRemoved(address indexed lender, address[] asset, uint256[] amount);

    function addAssets(address[] calldata assets, uint256[] calldata amounts) public override {
        _addAssets(assets, amounts);
        emit LenderAssetsAdded(msg.sender, assets, amounts);
    }

    function removeAssets(address[] calldata assets, uint256[] calldata amounts) public override {
        _removeAssets(assets, amounts);
        emit LenderAssetsRemoved(msg.sender, assets, amounts);
    }
}

contract BorrowerAccounts is Accounts {
    event BorrowerAssetsAdded(address indexed borrower, address[] asset, uint256[] amount);
    event BorrowerAssetsRemoved(address indexed borrower, address[] asset, uint256[] amount);

    function addAssets(address[] calldata assets, uint256[] calldata amounts) public override {
        _addAssets(assets, amounts);
        emit BorrowerAssetsAdded(msg.sender, assets, amounts);
    }

    function removeAssets(address[] calldata assets, uint256[] calldata amounts) public override {
        _removeAssets(assets, amounts);
        emit BorrowerAssetsRemoved(msg.sender, assets, amounts);
    }
}
