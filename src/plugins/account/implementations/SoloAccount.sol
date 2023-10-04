// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {C} from "src/libraries/C.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH9} from "src/interfaces/external/IWETH9.sol";
import {Account} from "../Account.sol";
import {LibUtilsPublic} from "src/libraries/LibUtilsPublic.sol";

// All amounts are input and saved with 18 dec precision. conversions to asset decimals happen before transfering.
contract SoloAccount is Account {

    struct Asset {
        address addr;
        uint8 decimals;
    }

    struct Parameters {
        address owner;
        bytes32 salt;
    }

    mapping(bytes32 => mapping(bytes32 => uint256)) private balances; // Update mapping

    constructor(address bookkeeperAddr) Account(bookkeeperAddr) {}

    function _loadFromUser(bytes memory assetData, uint256 amount, bytes memory parameters) internal override {
        _load(assetData, amount, parameters);
    }

    function _loadFromPosition(bytes memory assetData, uint256 amount, bytes memory parameters) internal override {
        _load(assetData, amount, parameters);
    }

    function _load(bytes memory assetData, uint256 amount, bytes memory parameters) private {
        Asset memory asset = abi.decode(assetData, (Asset));
        Parameters memory params = abi.decode(parameters, (Parameters));
        bytes32 id = _getId(params.owner, params.salt);
        balances[id][keccak256(assetData)] += amount; // Update user balance
        uint256 decAdjAmount = (amount * 10**(asset.decimals))/C.RATIO_FACTOR;

        if (asset.addr == C.WETH && msg.value > 0) {
            require(msg.value == amount, "ETH amount mismatch");
            IWETH9(C.WETH).deposit{value: msg.value}();
        } else {
            LibUtilsPublic.safeErc20TransferFrom(asset.addr, msg.sender, address(this), decAdjAmount);
        }
    }

        function _loadFromLiquidator (address liquidator, bytes memory assetData, uint256 amount, bytes memory parameters) internal override  {
        Asset memory asset = abi.decode(assetData, (Asset));
        Parameters memory params = abi.decode(parameters, (Parameters));
        bytes32 id = _getId(params.owner, params.salt);
        balances[id][keccak256(assetData)] += amount; // Update user balance
        uint256 decAdjAmount = (amount * 10**(asset.decimals))/C.RATIO_FACTOR;
        LibUtilsPublic.safeErc20TransferFrom(asset.addr, liquidator, address(this), decAdjAmount);
        
    }

    function _unloadToUser(bytes memory assetData, uint256 amount, bytes memory parameters) internal override {
        Asset memory asset = abi.decode(assetData, (Asset));
        Parameters memory params = abi.decode(parameters, (Parameters));
        require(msg.sender == params.owner, "unload: not owner");

        bytes32 id = _getId(params.owner, params.salt);

        require(balances[id][keccak256(assetData)] >= amount, "_unloadToUser: balance too low");
        balances[id][keccak256(assetData)] -= amount;

        uint256 decAdjAmount = amount * 10**(asset.decimals)/C.RATIO_FACTOR;

        if (asset.addr == C.WETH) {
            IWETH9(C.WETH).withdraw(amount);
            payable(msg.sender).transfer(amount);
        } else {
            LibUtilsPublic.safeErc20Transfer(asset.addr, msg.sender, decAdjAmount);
        }
    }

    function _unloadToPosition(
        address position,
        bytes memory assetData,
        uint256 amount,
        bytes memory parameters
    ) internal override onlyRole(C.BOOKKEEPER_ROLE) {
        Asset memory asset = abi.decode(assetData, (Asset));
        Parameters memory params = abi.decode(parameters, (Parameters));

        bytes32 id = _getId(params.owner, params.salt);
        uint256 decAdjAmount = amount * 10**(asset.decimals)/C.RATIO_FACTOR;

        require(balances[id][keccak256(assetData)] >= amount, "_unloadToPosition: balance too low");

        balances[id][keccak256(assetData)] -= amount;

        LibUtilsPublic.safeErc20Transfer(asset.addr, position, decAdjAmount);
    }

    function getOwner(bytes calldata parameters) external pure override returns (address) {
        return abi.decode(parameters, (Parameters)).owner;
    }

    function getBalance(
        bytes calldata assetData,
        bytes calldata parameters
    ) external view override returns (uint256 amounts) {
        Parameters memory params = abi.decode(parameters, (Parameters));
        bytes32 accountId = _getId(params.owner, params.salt);
        return balances[accountId][keccak256(assetData)];
    }

    function _getId(address owner, bytes32 salt) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, salt));
    }
}
