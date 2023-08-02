// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Asset, PluginRef} from "src/libraries/LibUtils.sol";

// Assets can exist in 3 places: EOAs, accounts, positions
// It may have a different representation in each of these positions.
// ^^ state machine, but no state, only lib?

// another issue this could address is plugin use of loadFromUser vs loadFromPosition, which is susceptible to abuse

// another note is that any account/pos will be able to hold any asset for a user, even if they cannot meaningfully use it.

// Are all transfers handled by bookkeeper? no bc liquidations.
// what does this mean for 'trust'? users bear consequences of picking bad plugins. is ok as long as other users are safe.

/*

account -> pos
coll lock in account (?)
pos -> account
pos -> user (unload, liquidate)
account -> user

each of these transitions require informing the sender and receiver of the action, which is where the bulk of complexity comes from.
two types of sender/receiver: eoa and contract   <- eoa never needs send/receive information




sort of a state machine with 3 states. assume assets can move directly between any of these states.
1. user
2. account plugin
3. position plugin instance (controlled by either bookkeeper or liquidator plugin)

^^ these states imply 3 types of transitions
1. userToPlugin
2. PluginToUser
3. PluginToPlugin 

there are 3 types of transfers
1. push (plugin -> user/plugin)
2. pull (plugin -> user/plugin)
3. move (user/plugin -> user/plugin)

there is some scope restriction derived from eoa inability to push, and plugin push preference, so we have   // bk management, trust limits
- pullFromUser
- pushToUser
- pushToPlugin (account <-> position)
^^ this makes sense, since account or pos would never allow anyone but bk to pull assets and bk can just call push instead

^^ pushing is a problem. bc it would need to be called as a delegateCall in the pusher plugin. This means arbitrary
    third party code can be run in the state space of plugins, which could affect other users' assets in accounts.
 possible options: accounts as MPCs, lean harder on MPC assumptions of positions, push all control to bk.
:(
 - accounts as MPCs introduce upfront gas cost and complexity for UX. but it is elegant. limits damage of hostile plugins/asset controllers.
 - not sure everything we need can be shifted to positions. e.g. push/pull with user loading/unloading accounts
 - push control to bk has problems with niche assets that do not have 3rd party transfer functionality

what is delta if accounts as MPCs?
1. when user creates a new account they will have to pay. generally this will coincide with a load, so it can be presented
    as one txn with one time higher cost for user.
2. intrinsic improvements on asset isolation and security. also parity with position design (all asset handler plugins same)

Another alt idea: channel all account calls through the bk, which verifies order and appropriateness. this way the 
account contract is executing unknown code in state space, but only if valid agreement.
^^ sike this doesn't work for same reason, one agreement puts non-involved users' funds at risk.


*/

// enum ActorType {
//     EOA,
//     ACCOUNT,
//     POSITION

//     // alt
//     USER,
//     PLUGIN // no need to support plugin callbacks for user smart contracts
// }

// struct Asset {
//     ;
// }

// interface IAssetHolder {

//     function pull(); // load account, liquidation
//     function push(); // open pos, close pos, liquidation
//     function move();

//     function recordSend();

//     function recordReceive();

//     // useful for invariants
//     function balance();
// }

// interface IAssetControl {
//     function transfer(address from, ActorType fromType, address to, ActorType toType);

//     function transferAccountToPosition();

//     function transferPositionToAccount();

//     // useful for invariants
//     function getBalance();

//     // alt
//     // can assume the source is always a plugin? no, bc liquidations and accounts should be able to use this abstraction
//     function transferToAccount();
//     function transferToPosition();
//     function transferToUser(); // eoa or contract

//     // alt
//     // pull and push will have 1 side known context as plugin
//     function pull(); // load account, liquidation
//     function push(); // open pos, close pos, liquidation
//     function move();

//     // alt
//     // pull and push will have 1 side known context as plugin
//     function pullFromUser(); // load account, liquidation
//     function pushToPlugin(); // open pos, close pos, liquidation
// }

// contract AssetControl is IAssetControl {

//     function transferToAccount(address from, ) {
//         _transfer(
//     }
//     function transferToPosition();
//     function transferToUser(); // eoa or contract

//         function _transfer(address from, bytes fromData, ActorType fromType address to, bytes toData, ActorType toType) specialnonreentrant {

// }

// contract LibErc20Control is ILibAssetControl {
//     function transfer(address from, bytes fromData, ActorType fromType address to, bytes toData, ActorType toType) specialnonreentrant {
//         if (from is not eoa) {
//             // account updates user balance; pos might do nothing;
//             // how to distinguish from user vs from pos? does it matter if MPC? could be managed in load call directly, such
//             //  that use of load implies from user and otherwise from pos, but both use this logic.
//             Ifrom.recordSend(asset, amount, fromdata);
//         }
//         if (to is not eoa) {
//             // account updates user balance; pos might do nothing;
//             Ito.recordReceive(asset, amount, todata);
//         }
//         require(asset.standard == ERC20_STANDARD);
//         if (from == address(this)) {
//             IERC20(asset.addr).safeTransfer(amount, to);
//         } else {
//             IERC20(asset.addr).safeTransferFrom(amount, from, to);
//         }
//     }

// }

// pullToAccount
// pushFromAccount
// PushToAccount

// pushU2A
// pullA2U

// assets are unaware of whether they are locked or not. they do not care. bookkeeper+account will track.
// thus there are 3 states: held by user, held by account plugin, held by terminal plugin. thus there are 6 possible
// transitions btwn states. each transition should be defined by the plugin implementor, as different assets may
// need unique transition logic and appear in different forms while in different plugins.
// for example, if a terminal only supports erc20s it would be possible to implement an asset with native staking of
// a token in a way that *only* requires implementation of an Asset contract. Account implementations do not need
// to understand the asset at all (i.e. SoloAccount) and the asset can be converted to a compatible erc20 before
// being transferred to the Terminal.

// we can determine recipient type such that we will never mistake an eoa for a contract.

interface IFreighter {
    function pullToPort(Asset calldata asset, uint256 amount, address from, bytes calldata parameters) external;

    function pullToTerminal(Asset calldata asset, uint256 amount, address from, bytes calldata parameters) external;

    function pushFromPort(Asset calldata asset, uint256 amount, address to, bytes calldata parameters) external;

    function pushFromTerminal(Asset calldata asset, uint256 amount, address to, bytes calldata parameters) external;

    function portReceiptCallback(Asset calldata asset, uint256 amount, bytes calldata parameters) external;

    function terminalReceiptCallback(Asset calldata asset, uint256 amount, bytes calldata parameters) external;
}

// NOTE it is not safe for the bookkeeper to (delegate) call Freighters bc the bk contains shared state.
