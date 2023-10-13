// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {C} from "src/libraries/C.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH9} from "src/interfaces/external/IWETH9.sol";
import {Account} from "../Account.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {LibUtilsPublic} from "src/libraries/LibUtilsPublic.sol";

// All amounts are input and saved with 18 dec precision. conversions to asset decimals happen before transfering.
contract SoloAccount is Account {

    struct Asset {
        uint8 standard; // asset type, 1 for ERC20, 2 for ERC721, 3 for ERC1155
        address addr; 
        uint8 decimals; //not used if ERC721
        uint256 tokenId; // for ERC721 and ERC1155
        bytes data;
    }

    struct Parameters {
        address owner;
        bytes32 salt;
    }
    struct FillerData{
        uint256 tokenId;
        address account;
    }

    mapping(bytes32 => mapping(bytes32 => uint256)) private balances; // Update mapping

    constructor(address bookkeeperAddr) Account(bookkeeperAddr) {}

    function _loadFromUser(bytes memory assetData, uint256 amount, bytes memory accountParameters) internal override {
        _load(assetData, amount, accountParameters);
    }

    function _loadFromPosition(bytes memory assetData, uint256 amount, bytes memory accountParameters) internal override {
        _load(assetData, amount, accountParameters);
    }

    function _load(bytes memory assetData, uint256 amount, bytes memory accountParameters) private {
        Asset memory asset = abi.decode(assetData, (Asset));
        Parameters memory params = abi.decode(accountParameters, (Parameters));
        bytes32 id = _getId(params.owner, params.salt);
        balances[id][keccak256(assetData)] += amount; // Update user balance
        uint256 decAdjAmount = (amount * 10**(asset.decimals))/C.RATIO_FACTOR;

        if (asset.addr == C.WETH && msg.value > 0) {
            require(msg.value == amount, "ETH amount mismatch");
            IWETH9(C.WETH).deposit{value: msg.value}();
        } else {
            if (asset.standard == 1) {  // ERC-20
                LibUtilsPublic.safeErc20TransferFrom(asset.addr, msg.sender, address(this), decAdjAmount);
            } else if (asset.standard == 2) {  // ERC-721
                LibUtilsPublic.safeErc721TransferFrom(asset.addr, msg.sender, address(this), asset.tokenId, asset.data);
            } else if (asset.standard == 3) {  // ERC-1155
                LibUtilsPublic.safeErc1155TransferFrom(asset.addr,msg.sender, address(this), asset.tokenId, decAdjAmount, asset.data);

            } else {
                revert("Unsupported asset standard");
            }
        }
    }

    function _unloadToUser(bytes memory assetData, uint256 amount, bytes memory accountParameters) internal override {
         Asset memory asset = abi.decode(assetData, (Asset));
        Parameters memory params = abi.decode(accountParameters, (Parameters));
        require(msg.sender == params.owner, "unload: not owner");

        bytes32 id = _getId(params.owner, params.salt);

        require(balances[id][keccak256(assetData)] >= amount, "_unloadToUser: balance too low");
        balances[id][keccak256(assetData)] -= amount;

        uint256 decAdjAmount = amount * 10**(asset.decimals)/C.RATIO_FACTOR;

       if (asset.addr == C.WETH && msg.value > 0) {
            require(msg.value == amount, "ETH amount mismatch");
            IWETH9(C.WETH).deposit{value: msg.value}();
        } else {
            if (asset.standard == 1) {  // ERC-20
                LibUtilsPublic.safeErc20Transfer(asset.addr, msg.sender, decAdjAmount);
            } else if (asset.standard == 2) {  // ERC-721
                LibUtilsPublic.safeErc721TransferFrom(asset.addr,  address(this),msg.sender, asset.tokenId, asset.data);
            } else if (asset.standard == 3) {  // ERC-1155
                LibUtilsPublic.safeErc1155TransferFrom(asset.addr, address(this),msg.sender, asset.tokenId, decAdjAmount, asset.data);

            } else {
                revert("Unsupported asset standard");
            }
        }
    }

    function _unloadToPosition(
        address position,
        bytes memory assetData,
        uint256 amount,
        bytes memory accountParameters,
        bytes memory fillerData
    ) internal override onlyRole(C.BOOKKEEPER_ROLE) {
        Asset memory asset = abi.decode(assetData, (Asset));
         if ((asset.standard == 2 || asset.standard == 3) && asset.tokenId == 0){
            FillerData memory fillerDataDecoded = abi.decode(fillerData,(FillerData));
            asset.tokenId = fillerDataDecoded.tokenId;
            assetData= abi.encode(Asset({standard: asset.standard, addr: asset.addr, decimals: asset.decimals, tokenId: asset.tokenId, data: asset.data}));
        }
        Parameters memory params = abi.decode(accountParameters, (Parameters));
        uint256 decAdjAmount = amount * 10**(asset.decimals)/C.RATIO_FACTOR;

        bytes32 id = _getId(params.owner, params.salt);
        require(balances[id][keccak256(assetData)] >= 0, "_unloadToPosition: balance too low");
        balances[id][keccak256(assetData)] -= amount;

        if (asset.standard == 1) {  // ERC-20
                LibUtilsPublic.safeErc20Transfer(asset.addr,  position,  decAdjAmount);
            } else if (asset.standard == 2) {  // ERC-721
                LibUtilsPublic.safeErc721TransferFrom(asset.addr,address(this), position,  asset.tokenId, asset.data);
            } else if (asset.standard == 3) {  // ERC-1155
                //LibUtilsPublic.safeErc1155TransferFrom(asset.addr, msg.sender, address(this), asset.tokenId, decAdjAmount, asset.data);
                LibUtilsPublic.safeErc1155TransferFrom(asset.addr, address(this), position,  asset.tokenId, decAdjAmount, asset.data);

            } else {
                revert("Unsupported asset standard");
            }

    }


    function getOwner(bytes calldata parameters) external pure override returns (address) {
        return abi.decode(parameters, (Parameters)).owner;
    }

    function getBalance(
        bytes memory assetData,
        bytes calldata parameters,
        bytes calldata fillerData
    ) external view override returns (uint256 amounts) {
        Parameters memory params = abi.decode(parameters, (Parameters));
         Asset memory asset = abi.decode(assetData, (Asset));
         if ((asset.standard == 2 || asset.standard == 3) && asset.tokenId == 0){
            FillerData memory fillerDataDecoded = abi.decode(fillerData,(FillerData));
            asset.tokenId = fillerDataDecoded.tokenId;
            assetData= abi.encode(Asset({standard: asset.standard, addr: asset.addr, decimals: asset.decimals, tokenId: asset.tokenId, data: asset.data}));
        }
        bytes32 accountId = _getId(params.owner, params.salt);
        return balances[accountId][keccak256(assetData)];
    }

    function _getId(address owner, bytes32 salt) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, salt));
    }

    
}
