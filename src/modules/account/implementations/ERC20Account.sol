// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {C} from "src/C.sol";
import {Asset, ERC20_STANDARD} from "src/LibUtil.sol";
import {Account} from "../Account.sol";
import {IWETH9} from "src/interfaces/external/IWETH9.sol";
import "src/LibUtil.sol";

// NOTE could bypass need here (and other modules) for C.BOOKKEEPER_ROLE by verifying signed agreement and tracking
//      which have already been processed.

/**
 * Account for holding ETH and ERC20 assets, to use for either lending or borrowing through an Agreement.
 * ~ Not compatible with other asset types ~
 */
contract ERC20Account is Account {
    struct Parameters {
        address owner;
        // An owner-unique id for this account.
        bytes32 salt;
    }

    mapping(bytes32 => mapping(bytes32 => uint256)) private accounts; // account id => asset hash => amount

    constructor(address bookkeeperAddr) Account(bookkeeperAddr) {
        // COMPATIBLE_LOAN_ASSETS.push(Asset({standard: ERC20_STANDARD, addr: address(0), id: 0, data: ""}));
        // COMPATIBLE_COLL_ASSETS.push(Asset({standard: ERC20_STANDARD, addr: address(0), id: 0, data: ""}));
    }

    function _load(Asset calldata asset, uint256 amount, bytes calldata parameters) internal override {
        Parameters memory params = abi.decode(parameters, (Parameters));
        _increaseBalance(asset, amount, params);

        if (msg.value > 0 && asset.addr == C.WETH) {
            assert(msg.value == amount);
            IWETH9(C.WETH).deposit{value: msg.value}();
        } else {
            Utils.safeErc20TransferFrom(asset.addr, msg.sender, address(this), amount);
        }
    }

    function _unload(Asset calldata asset, uint256 amount, bytes calldata parameters) internal override {
        Parameters memory params = abi.decode(parameters, (Parameters));
        require(msg.sender == params.owner, "unload: not owner");
        _decreaseBalance(asset, amount, params);
        Utils.safeErc20Transfer(asset.addr, msg.sender, amount);
    }

    function _transferToPosition(
        address position,
        Asset calldata asset,
        uint256 amount,
        bool isLockedAsset,
        bytes calldata parameters
    ) internal override onlyRole(C.BOOKKEEPER_ROLE) {
        Parameters memory params = abi.decode(parameters, (Parameters));

        bytes32 id = _getId(params.owner, params.salt);
        if (!isLockedAsset) {
            accounts[id][keccak256(abi.encode(asset))] -= amount;
        }
        Utils.safeErc20Transfer(asset.addr, position, amount);
    }

    // Without wasting gas on ERC20 transfer, lock assets here. In normal case (healthy position close) no transfers
    // of collateral are necessary.
    function _lockCollateral(Asset calldata asset, uint256 amount, bytes calldata parameters)
        internal
        override
        onlyRole(C.BOOKKEEPER_ROLE)
    {
        Parameters memory params = abi.decode(parameters, (Parameters));

        bytes32 id = _getId(params.owner, params.salt);
        accounts[id][keccak256(abi.encode(asset))] -= amount;
    }

    function _unlockCollateral(Asset calldata asset, uint256 amount, bytes calldata parameters)
        internal
        override
        onlyRole(C.BOOKKEEPER_ROLE)
    {
        Parameters memory params = abi.decode(parameters, (Parameters));

        bytes32 id = _getId(params.owner, params.salt);
        accounts[id][keccak256(abi.encode(asset))] += amount;
    }

    function getOwner(bytes calldata parameters) external pure override returns (address) {
        return abi.decode(parameters, (Parameters)).owner;
    }

    function canHandleAsset(Asset calldata asset, bytes calldata) external pure override returns (bool) {
        if (asset.standard == ERC20_STANDARD) return true;
        return false;
    }

    function getBalance(Asset calldata asset, bytes calldata parameters)
        external
        view
        override
        returns (uint256 amounts)
    {
        Parameters memory params = abi.decode(parameters, (Parameters));
        bytes32 accountId = _getId(params.owner, params.salt);
        return accounts[accountId][keccak256(abi.encode(asset))];
    }

    function _increaseBalance(Asset calldata asset, uint256 amount, Parameters memory params) private {
        accounts[_getId(params.owner, params.salt)][keccak256(abi.encode(asset))] += amount;
    }

    function _decreaseBalance(Asset calldata asset, uint256 amount, Parameters memory params) private {
        accounts[_getId(params.owner, params.salt)][keccak256(abi.encode(asset))] -= amount;
    }

    function _getId(address owner, bytes32 salt) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, salt));
    }
}
