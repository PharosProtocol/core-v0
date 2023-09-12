// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {C} from "src/libraries/C.sol";
import {Account} from "../Account.sol";
import {IWETH9} from "src/interfaces/external/IWETH9.sol";
import {Asset, ERC20_STANDARD, LibUtils} from "src/libraries/LibUtils.sol";
import {LibUtilsPublic} from "src/libraries/LibUtilsPublic.sol";

// SECURITY although unlikely, in the extreme situation of bad debt it is possible that a position never closes and
//          returns assets to the account. Although *if* a position does close it will always close with the amount
//          dictated by loan amount + assessor cost. Though, a malicious terminal could be designed to return less. When
//          less is returned, what will happen to uninvolved lenders using the same account contract? Does this
//          allow a bad actor to extract assets from a shared account contract instance by taking both sides
//          of an agreement with a malicious terminal?
//          No. At least it is safe for Solo Account, because balances are handled per user. This may be a security
//          driver for implementing accounts as MPCs though.

/**
 * Account for holding ERC20 assets, to use for either lending or borrowing through an Agreement.
 * ~ Not compatible with other asset types ~
 */
contract SoloAccount is Account {
    struct Parameters {
        address owner;
        // An owner-unique id for this account.
        bytes32 salt;
    }

    mapping(bytes32 => mapping(bytes32 => uint256)) private unlockedBalances; // account id => asset hash => amount

    constructor(address bookkeeperAddr) Account(bookkeeperAddr) {}

    function _loadFromUser(Asset calldata asset, uint256 amount, bytes calldata parameters) internal override {
        _load(asset, amount, parameters);
    }

    function _loadFromPosition(Asset calldata asset, uint256 amount, bytes calldata parameters) internal override {
        _load(asset, amount, parameters);
    }

    function _load(Asset calldata asset, uint256 amount, bytes calldata parameters) private {
        Parameters memory params = abi.decode(parameters, (Parameters));
        bytes32 id = _getId(params.owner, params.salt);
        bytes32 assetHash = keccak256(abi.encode(asset));
        unlockedBalances[id][assetHash] = LibUtils.addWithMsg(
            unlockedBalances[id][assetHash],
            amount,
            "_load: balance too large"
        );

        if (msg.value > 0 && asset.addr == C.WETH) {
            assert(msg.value == amount);
            IWETH9(C.WETH).deposit{value: msg.value}();
        } else {
            LibUtilsPublic.safeErc20TransferFrom(asset.addr, msg.sender, address(this), amount);
        }
    }

    function _unloadToUser(Asset calldata asset, uint256 amount, bytes calldata parameters) internal override {
        Parameters memory params = abi.decode(parameters, (Parameters));
        require(msg.sender == params.owner, "unload: not owner");
        bytes32 id = _getId(params.owner, params.salt);
        bytes32 assetHash = keccak256(abi.encode(asset));
        unlockedBalances[id][assetHash] = LibUtils.subWithMsg(
            unlockedBalances[id][assetHash],
            amount,
            "_unloadToUser: balance too low"
        );
        LibUtilsPublic.safeErc20Transfer(asset.addr, msg.sender, amount);
    }

    function _unloadToPosition(
        address position,
        Asset calldata asset,
        uint256 amount,
        bool isLockedColl,
        bytes calldata parameters
    ) internal override onlyRole(C.BOOKKEEPER_ROLE) {
        Parameters memory params = abi.decode(parameters, (Parameters));

        bytes32 id = _getId(params.owner, params.salt);
        if (!isLockedColl) {
            bytes32 assetHash = keccak256(abi.encode(asset));
            unlockedBalances[id][assetHash] = LibUtils.subWithMsg(
                unlockedBalances[id][assetHash],
                amount,
                "_unloadToPosition: balance too low"
            );
        }
        // AUDIT any method to take out of other users locked balance?
        LibUtilsPublic.safeErc20Transfer(asset.addr, position, amount);
    }

    // Without wasting gas on ERC20 transfer, lock assets here. In normal case (healthy position close) no transfers
    // of collateral are necessary.
    function _lockCollateral(
        Asset calldata asset,
        uint256 amount,
        bytes calldata parameters
    ) internal override onlyRole(C.BOOKKEEPER_ROLE) {
        Parameters memory params = abi.decode(parameters, (Parameters));

        bytes32 id = _getId(params.owner, params.salt);
        bytes32 assetHash = keccak256(abi.encode(asset));
        unlockedBalances[id][assetHash] = LibUtils.subWithMsg(
            unlockedBalances[id][assetHash],
            amount,
            "_lockCollateral: balance too low"
        );
    }

    function _unlockCollateral(
        Asset calldata asset,
        uint256 amount,
        bytes calldata parameters
    ) internal override onlyRole(C.BOOKKEEPER_ROLE) {
        Parameters memory params = abi.decode(parameters, (Parameters));

        bytes32 id = _getId(params.owner, params.salt);
        bytes32 assetHash = keccak256(abi.encode(asset));
        unlockedBalances[id][assetHash] = LibUtils.addWithMsg(
            unlockedBalances[id][assetHash],
            amount,
            "_unlockCollateral: balance too large"
        );
    }

    function getOwner(bytes calldata parameters) external pure override returns (address) {
        return abi.decode(parameters, (Parameters)).owner;
    }

    function canHandleAsset(Asset calldata asset, bytes calldata) external pure override returns (bool) {
        if (asset.standard == ERC20_STANDARD) return true;
        return false;
    }

    function getBalance(
        Asset calldata asset,
        bytes calldata parameters
    ) external view override returns (uint256 amounts) {
        Parameters memory params = abi.decode(parameters, (Parameters));
        bytes32 accountId = _getId(params.owner, params.salt);
        return unlockedBalances[accountId][keccak256(abi.encode(asset))];
    }

    function _getId(address owner, bytes32 salt) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, salt));
    }
}
