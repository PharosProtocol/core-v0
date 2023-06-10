// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import {C} from "src/C.sol";
import {IBookkeeper} from "src/interfaces/IBookkeeper.sol";
import {Order} from "src/bookkeeper/LibBookkeeper.sol";
import {Asset, ERC20_STANDARD} from "src/LibUtil.sol";
import {CloneFactory} from "src/modules/CloneFactory.sol";
import {Account} from "../Account.sol";
import {IWETH9} from "src/interfaces/external/IWETH9.sol";
import "src/LibUtil.sol";

/**
 * PoolAccount is one possible implementation of how an account can be implemented to pool user assets.
 * This particular implementation is used for supplying assets and allows for many different independent pools. Each
 * pool can hold one ERC20 assets. Rewards earned by the pool are distributed proportionally to all users.
 *
 * This implementation is not compatible with borrowing. It is only for supplying assets to the pool.
 *
 * Notable limitations:
 *  - Rewards do not compound earn for users.
 */

// SECURITY although unlikely, in the extreme situation of bad debt it is possible that a position never closes and
//          returns assets to the account. Although *if* a position does close it will always close with the amount
//          dictated by the assessor. We would expect this to be at least the same as the initial amount, but a bad
//          actor could design an assessor that returns less. When less is returned, what will happen to lenders in
//          this type of account? They will be able to withdraw, but it will be a smaller amount than they put in. 
//          However, each account has a known Order and Assessor assigned at creation, so users are agreeing to the
//          terms, even if they are bad. 

// Could track historical utilization by using summation system located in the account. Assessors could then pull
// cumulative utilization since agreement inception and use it to price loan cost without any state in the
// assessor itself. This resolves design weirdness seen in src/_laboratory/UtilizationBasedInterest.sol
// resulting from the indirect storage of account utilization in the assessor.

// Utilization always changes at position creation time, so we will always have an entry in a summation time->sum
// mapping that represents the beginning of a position. and current sum is known. thus back computing average
// utilization over a time frame is possible in constant time.

// IDEA implement multiple pools in one contract instance
// IDEA allow multiple orders per pool/contract instance (does not work with current interface ppl any order can access all funds)
// IDEA improve math to enable full compounding of rewards.
// IDEA Utilization could be shared between all assets in account, rather than per-asset.

contract PoolSupplyAccount is Account {
    struct Parameters {
        // bytes32 poolId; // A unique id for a pool.
        address user;
    }

    // One order per pool account contract. One pool per address.
    constructor(address bookkeeperAddr, Order memory order) Account(bookkeeperAddr) {
        IBookkeeper(bookkeeperAddr).signPublishOrder(order);
    }

    // Amount of assets currently in the pool available to be used.
    mapping(bytes32 => uint256) private available; // asset hash => balance
    // Amount of (known) assets this pool under management of this pool as its associated positions.
    mapping(bytes32 => uint256) private supply; // asset hash => supply

    uint256 utilization;
    mapping(uint256 => mapping(bytes32 => uint256)) private utilizationSum; // time => asset hash => utilization sum
    mapping(bytes32 => uint256) private utilizationLastUpdated;

    // Marks indicate entitlement to assets.

    // QUESTION GAS does embedding of many layers of map create high lookup cost?
    mapping(bytes32 => uint256) private marks; // asset hash =>
    mapping(bytes32 => uint256) private marksSum; // asset hash => total ownership count
    mapping(bytes32 => uint256) private marksLastUpdated; // asset hash =>

    // The amount contributed by a user. This is the amount sum will increase by each second.
    mapping(address => mapping(bytes32 => uint256)) private userMarks; // user => asset hash => balance
    mapping(address => mapping(bytes32 => uint256)) private userMarksSum; // user => asset hash => balance
    mapping(address => mapping(bytes32 => uint256)) userMarksLastUpdated;

    /// @notice Get time weighted average utilization from startTime to now.
    function getTWAUtilization(Asset calldata asset, uint256 startTime, bytes calldata parameters)
        external
        view
        returns (uint256)
    {
        Parameters memory params = abi.decode(parameters, (Parameters));
        bytes32 assetHash = keccak256(abi.encode(asset));
        uint256 startSum = utilizationSum[startTime][assetHash];
        uint256 currentSum = utilizationSum[utilizationLastUpdated][assetHash] +=
            utilization * (block.timestamp - utilizationLastUpdated[assetHash]);
        // require(startSum != 0, "getTWAUtilization: no start sum");
        // GAS utilizationSum can use unchecked sub.
        return (currentSum - startSum) / (block.timestamp - startTime);
    }

    function _loadFromUser(Asset calldata asset, uint256 amount, bytes calldata parameters) internal override {
        Parameters memory params = abi.decode(parameters, (Parameters));
        bytes32 assetHash = keccak256(abi.encode(asset));

        if (msg.value > 0 && asset.addr == C.WETH) {
            assert(msg.value == amount);
            IWETH9(C.WETH).deposit{value: msg.value}();
        } else {
            // NOTE SECURITY fee on transfer erc20s.
            Utils.safeErc20TransferFrom(asset.addr, msg.sender, address(this), amount);
        }

        _updateMarksSum(assetHash);
        marks[assetHash] += amount;
        _updateUserMarksSum(params.user, assetHash);
        userMarks[params.user][assetHash] += amount;

        available[assetHash] += amount;
        supply[assetHash] += amount;

        _updateUtilizationAndSum(assetHash);
    }

    function _loadFromPosition(Asset calldata asset, uint256 amount, int256 change, bytes calldata parameters)
        internal
        override
    {
        Parameters memory params = abi.decode(parameters, (Parameters));
        bytes32 assetHash = keccak256(abi.encode(asset));

        if (msg.value > 0 && asset.addr == C.WETH) {
            assert(msg.value == amount);
            IWETH9(C.WETH).deposit{value: msg.value}();
        } else {
            // SECURITY fee on transfer erc20s.
            Utils.safeErc20TransferFrom(asset.addr, msg.sender, address(this), amount);
        }
        available[assetHash] += amount;

        // SECURITY would we ever see a number so large this conversion fails?
        if (change >= 0) {
            supply[assetHash] += uint256(change);
        } else {
            // SECURITY Can change ever be larger than poolSupply ?
            supply[assetHash] -= uint256(change);
        }

        _updateUtilizationAndSum(assetHash);
    }

    function _unloadToUser(Asset calldata asset, uint256 amount, bytes calldata parameters) internal override {
        Parameters memory params = abi.decode(parameters, (Parameters));
        bytes32 assetHash = keccak256(abi.encode(asset));
        require(msg.sender == params.user, "unload: not owner");

        // SECURITY could rounding errors below cause a tiny shortage of funds leading to locking?

        // Determine proportional marks and amount.
        uint256 unloadMarks;
        if (amount == type(uint256).max) {
            unloadMarks = userMarks[params.user][assetHash];
            amount = unloadMarks * supply[assetHash] / marks[assetHash];
        } else {
            unloadMarks = marks[assetHash] * amount / supply[assetHash];
        }

        _updateMarksSum(assetHash);
        marks[assetHash] -= unloadMarks;
        _updateUserMarksSum(params.user, assetHash);
        userMarks[params.user][assetHash] -= unloadMarks;

        available[assetHash] -= amount;
        supply[assetHash] -= amount;

        _updateUtilizationAndSum(assetHash);

        // SECURITY fee on transfer erc20s.
        Utils.safeErc20Transfer(asset.addr, params.user, amount);
    }

    /// @dev Not configured to handle borrowing (locked assets).
    function _unloadToPosition(address position, Asset calldata asset, uint256 amount, bool, bytes calldata parameters)
        internal
        override
        onlyRole(C.BOOKKEEPER_ROLE)
    {
        Parameters memory params = abi.decode(parameters, (Parameters));
        bytes32 assetHash = keccak256(abi.encode(asset));

        available[assetHash] -= amount;

        _updateUtilizationAndSum(assetHash);

        // SECURITY fee on transfer erc20s.
        Utils.safeErc20Transfer(asset.addr, position, amount);
    }

    // Without wasting gas on ERC20 transfer, lock assets here. In normal case (healthy position close) no transfers
    // of collateral are necessary.
    function _lockCollateral(Asset calldata asset, uint256 amount, bytes calldata parameters)
        internal
        override
        onlyRole(C.BOOKKEEPER_ROLE)
    {
        revert("PoolAccount: Not compatible with borrowing");
    }

    function _unlockCollateral(Asset calldata asset, uint256 amount, bytes calldata parameters)
        internal
        override
        onlyRole(C.BOOKKEEPER_ROLE)
    {
        revert("PoolAccount: Not compatible with borrowing");
    }

    function getOwner(bytes calldata parameters) external pure override returns (address) {
        return address(this);
    }

    function canHandleAsset(Asset calldata asset, bytes calldata) external pure override returns (bool) {
        // SECURITY cannot handle fee on transfer erc20s.
        if (asset.standard == ERC20_STANDARD) return true;
        return false;
    }

    function getBalance(Asset calldata asset, bytes calldata parameters)
        external
        view
        override
        returns (uint256 amounts)
    {
        return available[keccak256(abi.encode(asset))];
    }

    function _updateMarksSum(bytes32 assetHash) private {
        uint256 deltaTime = block.timestamp - marksLastUpdated[assetHash];

        marksSum[assetHash] += marks[assetHash] * deltaTime;

        marksLastUpdated[assetHash] = block.timestamp;
    }

    function _updateUserMarksSum(address user, bytes32 assetHash) private {
        uint256 deltaTime = block.timestamp - userMarksLastUpdated[user][assetHash];

        userMarksSum[user][assetHash] += userMarks[user][assetHash] * deltaTime;

        userMarksLastUpdated[user][assetHash] = block.timestamp;
    }

    // NOTE would be safer if there was a data structure that let us request 'get at this timestamp or earlier'. Pretty
    //      sure this would require a binary search on an array of N size though.
    /// @notice Updates utilization and sum. Sets a new sum for the current time.
    function _updateUtilizationAndSum(bytes32 assetHash) private {
        uint256 deltaTime = block.timestamp - utilizationLastUpdated[assetHash];

        utilizationSum[block.timestamp][assetHash] += utilization * deltaTime;

        utilization = C.RATIO_FACTOR * (supply[assetHash] - available[assetHash]) / supply[assetHash];

        utilizationLastUpdated[assetHash] = block.timestamp;
    }
}
