// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

/*

import "forge-std/console.sol";

import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {Blueprint, SignedBlueprint} from "lib/tractor/Tractor.sol";

import {C} from "src/libraries/C.sol";
import {IBookkeeper} from "src/interfaces/IBookkeeper.sol";
import {Bookkeeper} from "src/bookkeeper.sol";
import {Order} from "src/libraries/LibBookkeeper.sol";
import {Asset, ERC20_STANDARD} from "src/libraries/LibUtils.sol";
import {CloneFactory} from "src/plugins/CloneFactory.sol";
import {Account} from "../Account.sol";
import {IWETH9} from "src/interfaces/external/IWETH9.sol";
import {LibUtilsPublic} from "src/libraries/LibUtilsPublic.sol";


//  * PoolAccount is one possible implementation of how an account can be implemented to pool user assets.
//  * This particular implementation is used for supplying assets and allows for many different independent pools. Each
//  * pool can hold one ERC20 assets. Rewards earned by the pool are distributed proportionally to all users.
//  *
//  * This implementation is not compatible with borrowing. It is only for supplying assets to the pool.
//  *
//  * Notable limitations:
//  *  - Rewards do not compound earn for users.


// SECURITY although unlikely, in the extreme situation of bad debt it is possible that a position never closes and
//          returns assets to the account. Although *if* a position does close it will always close with the amount
//          dictated by the assessor. We would expect this to be at least the same as the initial amount, but a bad
//          actor could design an assessor that returns less. When less is returned, what will happen to lenders in
//          this type of account? They will be able to withdraw, but it will be a smaller amount than they put in.
//          However, each account has a known Order and Assessor assigned at creation, so users are agreeing to the
//          terms, even if they are bad.

// SECURITY ensure correct behavior on first deposit.

// NOTE this contract pushes the limits of my economic knowledge and math ability. Likely has room for conceptual
//      improvement.

// SECURITY what happens in the case of bad debt? Last user to exit gets left holding bag of missing assets and cannot
//          withdraw.

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

contract PoolSupplyAccount is Account, IERC1271 {
    struct Parameters {
        // bytes32 poolId; // A unique id for a pool.
        address user;
    }

    mapping(bytes32 => bool) signedHashes;

    // Supply of pool can be (roughly) approximated as available + deployed. A reasonable order with reasonable assessor
    // will result in deployed always be equal or less than the amount that will be returned by closing positions. Thus
    // we can treat it as the minimum supply. Bad debt may never close.
    // We do not use supply here because it is not possible to (securely) determine the delta between original
    // amount and returned amount when closing a position.
    // Amount of assets currently in the pool available to be used.
    mapping(bytes32 => uint256) private available; // asset hash => balance
    // Amount of (known) assets that have been deployed to positions and not yet returned.
    mapping(bytes32 => uint256) private deployed; // asset hash => supply
    // // Amount of (known) assets this pool under management of this pool as its associated positions.
    // mapping(bytes32 => uint256) private supply; // asset hash => supply

    mapping(bytes32 => uint256) private utilization;
    mapping(uint256 => mapping(bytes32 => uint256)) private utilizationSum; // time => asset hash => utilization sum
    mapping(bytes32 => uint256) private utilizationLastUpdated;

    // Marks indicate entitlement to assets.

    // QUESTION GAS does embedding of many layers of map create high lookup cost?
    mapping(bytes32 => uint256) private contributions; // asset hash =>
    mapping(bytes32 => uint256) private marks; // asset hash => total ownership count
    mapping(bytes32 => uint256) private marksLastUpdated; // asset hash =>

    // The amount contributed by a user. This is the amount sum will increase by each second.
    mapping(address => mapping(bytes32 => uint256)) private userContributions; // user => asset hash => balance
    mapping(address => mapping(bytes32 => uint256)) private userMarks; // user => asset hash => balance
    mapping(address => mapping(bytes32 => uint256)) userMarksLastUpdated;

    // One order per pool account contract. One pool per address.
    constructor(address bookkeeperAddr, Order[] memory orders) Account(bookkeeperAddr) {
        IBookkeeper bookkeeper = IBookkeeper(bookkeeperAddr);
        for (uint256 i; i < orders.length; i++) {
            SignedBlueprint memory signedBlueprint;
            signedBlueprint.blueprint = Blueprint({
                publisher: address(this),
                data: bookkeeper.packDataField(bytes1(uint8(Bookkeeper.BlueprintDataType.ORDER)), abi.encode(orders[i])),
                maxNonce: type(uint256).max,
                startTime: block.timestamp,
                endTime: type(uint256).max
            });
            signedBlueprint.blueprintHash = bookkeeper.getBlueprintHash(signedBlueprint.blueprint);
            signedBlueprint.signature = bytes("1");
            signedHashes[signedBlueprint.blueprintHash] = true;
            bookkeeper.publishBlueprint(signedBlueprint);
        }
    }

    /// @notice Get time weighted average utilization from startTime to now.
    function getTWAUtilization(Asset calldata asset, uint256 startTime, bytes calldata)
        external
        view
        returns (uint256)
    {
        if (block.timestamp - startTime == 0) return 0;
        bytes32 assetHash = keccak256(abi.encode(asset));
        uint256 startSum = utilizationSum[startTime][assetHash];
        uint256 currentSum = utilizationSum[utilizationLastUpdated[assetHash]][assetHash]
            + utilization[assetHash] * (block.timestamp - utilizationLastUpdated[assetHash]);
        // require(startSum != 0, "getTWAUtilization: no start sum");
        // GAS utilizationSum can use unchecked sub.
        return (currentSum - startSum) / (block.timestamp - startTime);
    }

    function _loadFromUser(Asset calldata asset, uint256 amount, bytes calldata parameters) internal override {
        Parameters memory params = abi.decode(parameters, (Parameters));
        bytes32 assetHash = keccak256(abi.encode(asset));

        _updateMarksAndUser(params.user, assetHash);

        // // NOTE should standardize contribution updating logic
        // _refreshContributionsAndUser(params.user, assetHash)

        uint256 minSupply = available[assetHash] + deployed[assetHash];
        uint256 userAmount = userMarks[params.user][assetHash] == 0
            ? 0
            : minSupply * userMarks[params.user][assetHash] / marks[assetHash];

        // SECURITY could this ever get caught and block with reverts?
        uint256 deltaContributions = userAmount + amount - userContributions[params.user][assetHash];

        contributions[assetHash] += deltaContributions;
        userContributions[params.user][assetHash] = userAmount + amount;

        available[assetHash] += amount;

        _updateUtilizationAndSum(assetHash);

        if (msg.value > 0 && asset.addr == C.WETH) {
            assert(msg.value == amount);
            IWETH9(C.WETH).deposit{value: msg.value}();
        } else {
            // NOTE SECURITY fee on transfer erc20s.
            LibUtilsPublic.safeErc20TransferFrom(asset.addr, msg.sender, address(this), amount);
        }
    }

    function _loadFromPosition(Asset calldata asset, uint256 amount, bytes calldata) internal override {
        bytes32 assetHash = keccak256(abi.encode(asset));

        available[assetHash] += amount;
        if (deployed[assetHash] > amount) {
            deployed[assetHash] -= amount;
        } else {
            deployed[assetHash] = 0;
        }

        _updateUtilizationAndSum(assetHash);

        if (msg.value > 0 && asset.addr == C.WETH) {
            assert(msg.value == amount);
            IWETH9(C.WETH).deposit{value: msg.value}();
        } else {
            // SECURITY fee on transfer erc20s.
            LibUtilsPublic.safeErc20TransferFrom(asset.addr, msg.sender, address(this), amount);
        }
    }

    /// @dev unloadAmount == type(uint256).max will withdraw all.
    function _unloadToUser(Asset calldata asset, uint256 unloadAmount, bytes calldata parameters) internal override {
        Parameters memory params = abi.decode(parameters, (Parameters));
        bytes32 assetHash = keccak256(abi.encode(asset));
        require(msg.sender == params.user, "unload: not owner");

        // SECURITY could rounding errors below cause a tiny shortage of funds leading to locking?

        // // NOTE could use this check combined with init marks = 1*contribution to avoid same block weirdness.
        // if (userMarksLastUpdated[params.user][assetHash] == block.timestamp) {
        //     revert("Cannot withdraw in same block as deposit");

        _updateMarksAndUser(params.user, assetHash);

        // Determine proportional marks and amount.
        uint256 minSupply = available[assetHash] + deployed[assetHash];
        require(minSupply > 0, "_unloadToUser: asset minSupply == 0");

        uint256 userAmount = userMarks[params.user][assetHash] == 0
            ? 0
            : minSupply * userMarks[params.user][assetHash] / marks[assetHash];

        console.log("_unloadToUser: unloadAmount: %s", unloadAmount);
        console.log("_unloadToUser: userAmount: %s", userAmount);

        require(unloadAmount <= userAmount, "_unloadToUser: withdrawing above user amount");

        uint256 unloadMarks;
        if (unloadAmount == type(uint256).max) {
            unloadMarks = userMarks[params.user][assetHash];
            unloadAmount = userAmount;
        } else {
            unloadMarks = marks[assetHash] * unloadAmount / minSupply;
        }

        // NOTE should users have a way to update on the fly to compound returns?

        // NOTE SPECIAL CASE TO ALLOW WITHDRAWAL when deltaTime == 0

        // This puts all entitled amount into user contribution balance, less unloadAmount. At this point rewards
        // will begin compound earning. Contributions could grow or shrink.
        uint256 nextUserContributions = userAmount - unloadAmount; // might be 0 if withdraw > contributions
        // nextUserContributions may not always be <= userContributions bc non-accruing assets will be included.
        if (nextUserContributions > userContributions[params.user][assetHash]) {
            contributions[assetHash] += (nextUserContributions - userContributions[params.user][assetHash]);
        } else {
            contributions[assetHash] -= (userContributions[params.user][assetHash] - nextUserContributions);
        }
        userContributions[params.user][assetHash] = nextUserContributions;

        marks[assetHash] -= unloadMarks;
        // This sub verifies withdrawal is not larger than user entitlement.
        userMarks[params.user][assetHash] -= unloadMarks;

        available[assetHash] -= unloadAmount;

        _updateUtilizationAndSum(assetHash);

        // SECURITY fee on transfer erc20s.
        LibUtilsPublic.safeErc20Transfer(asset.addr, params.user, unloadAmount);
    }

    /// @dev Not configured to handle borrowing (locked assets).
    function _unloadToPosition(
        address position,
        Asset calldata asset,
        uint256 amount,
        bool isLockedColl,
        bytes calldata
    ) internal override onlyRole(C.BOOKKEEPER_ROLE) {
        require(isLockedColl == false, "PoolAccount: Not compatible with borrowing");

        bytes32 assetHash = keccak256(abi.encode(asset));

        require(available[assetHash] >= amount, "_unloadToPosition: amount greater than available");
        unchecked {
            available[assetHash] -= amount;
        }
        deployed[assetHash] += amount;

        _updateUtilizationAndSum(assetHash);

        // SECURITY fee on transfer erc20s.
        LibUtilsPublic.safeErc20Transfer(asset.addr, position, amount);
    }

    // Without wasting gas on ERC20 transfer, lock assets here. In normal case (healthy position close) no transfers
    // of collateral are necessary.
    function _lockCollateral(Asset calldata, uint256, bytes calldata)
        internal
        view
        override
        onlyRole(C.BOOKKEEPER_ROLE)
    {
        revert("PoolAccount: Not compatible with borrowing");
    }

    function _unlockCollateral(Asset calldata, uint256, bytes calldata)
        internal
        view
        override
        onlyRole(C.BOOKKEEPER_ROLE)
    {
        revert("PoolAccount: Not compatible with borrowing");
    }

    function getOwner(bytes calldata) external view override returns (address) {
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
        Parameters memory params = abi.decode(parameters, (Parameters));
        bytes32 assetHash = keccak256(abi.encode(asset));

        uint256 minSupply = available[assetHash] + deployed[assetHash];
        uint256 currentUserMarks = userMarks[params.user][assetHash]
            + userContributions[params.user][assetHash] * (block.timestamp - userMarksLastUpdated[params.user][assetHash]);
        uint256 currentMarks =
            marks[assetHash] + contributions[assetHash] * (block.timestamp - marksLastUpdated[assetHash]);
        return currentUserMarks == 0 ? 0 : minSupply * currentUserMarks / currentMarks;
    }

    /// @dev marks and user marks will be 0 until at least 1 block has passed.
    function _updateMarksAndUser(address user, bytes32 assetHash) private {
        uint256 deltaTime = block.timestamp - userMarksLastUpdated[user][assetHash];

        // FREI-IP Invariant. Relocate? Remove?
        require(marks[assetHash] >= userMarks[user][assetHash], "Invariant: marks !>= userMarks");

        marks[assetHash] += contributions[assetHash] * deltaTime;
        userMarks[user][assetHash] += userContributions[user][assetHash] * deltaTime;

        marksLastUpdated[assetHash] = block.timestamp;
        userMarksLastUpdated[user][assetHash] = block.timestamp;
    }

    // NOTE would be safer if there was a data structure that let us request 'get at this timestamp or earlier'. Pretty
    //      sure this would require a binary search on an array of N size though.
    /// @notice Updates utilization and sum. Sets a new sum for the current time.
    /// @dev if no assets available or deployed, utilization == 0.
    function _updateUtilizationAndSum(bytes32 assetHash) private {
        uint256 deltaTime = block.timestamp - utilizationLastUpdated[assetHash];

        utilizationSum[block.timestamp][assetHash] += utilization[assetHash] * deltaTime;

        // If no assets, utilization is 0.
        if (deployed[assetHash] + available[assetHash] == 0) {
            utilization[assetHash] = 0;
        } else {
            // If asset not present or unused hash, will revert.
            utilization[assetHash] = C.RATIO_FACTOR * deployed[assetHash] / (deployed[assetHash] + available[assetHash]);
        }

        utilizationLastUpdated[assetHash] = block.timestamp;
    }

    // /// @notice Incorporate all user entitlement to their contributions so that they can further earn.
    // /// @dev user contribution ensure marks are updated first.
    // function _refreshContributionsAndUser(address user, bytes32 assetHash) private {
    //     uint256 minSupply = available[assetHash] + deployed[assetHash];
    //     uint256 minUserEntitledAmount =
    //         userMarks[user][assetHash] == 0 ? 0 : minSupply * userMarks[user][assetHash] / marks[assetHash];

    //     // if user contributions is smaller that previous, do nothing.
    //     if (minUserEntitledAmount < userContributions[user][assetHash]) {
    //         // INVARIANT user contribution never declines. Because min supply never declines.
    //         // uint256 deltaContributions = userContributions[user][assetHash] - minUserEntitledAmount;
    //         // contributions[assetHash] -= deltaContributions;
    //         return;
    //     }

    //     uint256 deltaContributions = minUserEntitledAmount - userContributions[user][assetHash];
    //     contributions[assetHash] += deltaContributions;

    //     userContributions[params.user][assetHash] = minUserEntitledAmount;
    // }

    // AUDIT  sanity check on this 1271 implementation. Particularly use of signature.
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue) {
        if (keccak256(signature) == keccak256(bytes("1")) && signedHashes[hash]) return 0x1626ba7e;
        return "";
    }
}

*/
