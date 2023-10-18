// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IAccount} from "src/interfaces/IAccount.sol";
import {C} from "src/libraries/C.sol";
import {Position} from "src/plugins/position/Position.sol";
import {IAssessor} from "src/interfaces/IAssessor.sol";
import {Agreement} from "src/libraries/LibBookkeeper.sol";
import {LibUtilsPublic} from "src/libraries/LibUtilsPublic.sol";
import {IOracle} from "src/interfaces/IOracle.sol";


/*
 * Send assets directly to a user wallet. Used with no leverage loans.
 */

// NOTE leverage loans are not explicitly blocked but bookkeeper is expected to block it. UI can also take care.

contract WalletFactory is Position {
    struct Parameters {
        address owner;
        bytes32 salt;
    }
    struct Asset {
        uint8 standard; // asset type, 1 for ERC20, 2 for ERC721, 3 for ERC1155
        address addr; 
        uint8 decimals; //not used if ERC721
        uint256 tokenId; // for ERC721 and ERC1155
        bytes data;
    }
    struct FillerData{
        uint256 tokenId;
    }

    constructor(address protocolAddr) Position(protocolAddr) {}



    /// @dev assumes assets are already in Position.
    function _open(Agreement calldata agreement) internal override {
        Parameters memory params = abi.decode(agreement.borrowerAccount.parameters, (Parameters));
        Asset memory asset = abi.decode(agreement.loanAsset, (Asset));
        FillerData memory fillerAsset = abi.decode(agreement.fillerData, (FillerData));

        if ((asset.standard == 2 || asset.standard == 3) && asset.tokenId == 0){
            asset.tokenId = fillerAsset.tokenId;
        }
        uint256 decAdjAmount = agreement.loanAmount * 10**(asset.decimals)/C.RATIO_FACTOR;

        if (asset.standard == 1) {  // ERC-20
            LibUtilsPublic.safeErc20Transfer(asset.addr, params.owner, decAdjAmount);
        } else if (asset.standard == 2) {  // ERC-721
            LibUtilsPublic.safeErc721TransferFrom(asset.addr,  address(this),params.owner, asset.tokenId, asset.data);
        } else if (asset.standard == 3) {  // ERC-1155
            LibUtilsPublic.safeErc1155TransferFrom(asset.addr, address(this),params.owner, asset.tokenId, decAdjAmount, asset.data);

        } else {
            revert("Unsupported asset standard");
        }
        
    }

    function _unwind(Agreement calldata agreement) internal override {
        
    }

    function _close( Agreement calldata agreement, uint256 amountToLender) internal override  {
        Parameters memory borrowerParams = abi.decode(agreement.borrowerAccount.parameters, (Parameters));
        FillerData memory fillerAsset = abi.decode(agreement.fillerData, (FillerData));
        Asset memory loanAsset = abi.decode(agreement.loanAsset, (Asset));
        if ((loanAsset.standard == 2 || loanAsset.standard == 3) && loanAsset.tokenId == 0){
            loanAsset.tokenId = fillerAsset.tokenId;
        }
        Asset memory collAsset = abi.decode(agreement.collAsset, (Asset));
        if ((collAsset.standard == 2 || collAsset.standard == 3) && collAsset.tokenId == 0){
            collAsset.tokenId = fillerAsset.tokenId;
        }

        // approvals to transfer to lender account
        if (loanAsset.standard == 1) {  // ERC-20
            IERC20(loanAsset.addr).approve(agreement.lenderAccount.addr, amountToLender);
        } else if (collAsset.standard == 2) {  // ERC-721
            IERC721(collAsset.addr).setApprovalForAll(agreement.lenderAccount.addr, true);
        } else if (collAsset.standard == 3) {  // ERC-1155
            IERC1155(collAsset.addr).setApprovalForAll(agreement.lenderAccount.addr, true);
        } else {
            revert("Unsupported asset standard");
        }

        IAccount(agreement.lenderAccount.addr).loadFromPosition(
            agreement.loanAsset,
            amountToLender,
            agreement.lenderAccount.parameters
        );

        // send collateral to borrower directly 
        uint256 decAdjAmount = (agreement.collAmount * 10**(collAsset.decimals))/C.RATIO_FACTOR;
        if (collAsset.standard == 1) {  // ERC-20
            LibUtilsPublic.safeErc20Transfer(collAsset.addr, borrowerParams.owner, decAdjAmount);
        } else if (collAsset.standard == 2) {  // ERC-721
            LibUtilsPublic.safeErc721TransferFrom(collAsset.addr,  address(this),borrowerParams.owner, collAsset.tokenId, collAsset.data);
        } else if (collAsset.standard == 3) {  // ERC-1155
            LibUtilsPublic.safeErc1155TransferFrom(collAsset.addr, address(this),borrowerParams.owner, collAsset.tokenId, decAdjAmount, collAsset.data);

        } else {
            revert("Unsupported asset standard");
        }

    }

    // Public Helpers.

    function _getCloseAmount(Agreement memory agreement) internal override returns (uint256) {
        
        Asset memory asset = abi.decode(agreement.collAsset, (Asset));
        FillerData memory fillerAsset = abi.decode(agreement.fillerData, (FillerData));

         if ((asset.standard == 2 || asset.standard == 3) && asset.tokenId == 0){
            asset.tokenId = fillerAsset.tokenId;
        }
        address assetAddress = asset.addr;
        uint8 assetDecimals = asset.decimals;
        uint256 closeAmount;

        if (asset.standard == 1) {  // ERC-20
            uint256 balance = IERC20(assetAddress).balanceOf(address(this));
             closeAmount= balance * IOracle(agreement.collOracle.addr).getOpenPrice(agreement.collOracle.parameters,agreement.fillerData)/10**(assetDecimals) ;
                    
            } else if (asset.standard == 2) {  // ERC-721
            uint256 balance;
            address owner = IERC721(asset.addr).ownerOf(asset.tokenId);
            if(owner==address(this)){balance =1;}else{balance=0;}

            closeAmount= balance * IOracle(agreement.collOracle.addr).getOpenPrice(agreement.collOracle.parameters,agreement.fillerData)/10**(assetDecimals) ;
             
            } else if (asset.standard == 3) {  // ERC-1155
            uint256 balance = IERC1155(asset.addr).balanceOf( address(this), asset.tokenId);
             closeAmount= balance * IOracle(agreement.collOracle.addr).getOpenPrice(agreement.collOracle.parameters,agreement.fillerData)/10**(assetDecimals) ;
           
            } else {
                revert("Unsupported asset standard");
            }

        
        return closeAmount;
    }
}
