// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.17;

contract Registry {

    mapping(bytes32 => Valuator) valuators;
    mapping(bytes32 => TermSheet) termSheets;
    mapping(uint32 => Position) positions; // active loans

    // Need to figure out state sharing paradigm.
    // Bookkeeper bk; // = new SavingsAccont();


    // Two Ratio System:
    // Allows for profits to accumulate without being distributed.
    // Allows for different users' ownership % to grow at different rates (time awareness).
    // Not necessary, but would allow for stickyness system where older suppliers are rewarded
    // more.
    // uint256 entitlement; // similar to roots
    // uint256 circulating; // similar to stalk
    // Single Ratio System:
    // No distinction between position and profits.
    // Only allows for ownership proportianal distribution.
    // uint totalAssets;
    // uint totalOwnership;

    // total assets
    // user input assets 
    // user ownership at input

    constructor() {}

    function registerValuator(bytes32 calldata id, address calldata asset, bytes256 calldata valueFunction) public {
        require(asset != address(0)); // asset address is set.
        require(valuators[id].asset != address(0)); // id is not yet used.
        valuators[id] = Valuator(asset, valueFunction);
    }

    function registerTermSheet(bytes32 id, address asset, address terminal) public {
        require(asset != address(0)); // asset address is set.
        require(termSheets[id].asset != address(0)); // id is not yet used.
        termSheets[id] = TermSheet({
            asset: asset,
            terminal: terminal
            // .......
        });
    }

    // Savings Account -> Term Sheets.

    // Lendee fills Offer.
    function take(bytes32 borrowAccount, bytes32 supplyAccount, bytes32 termSheet,
                  address collateralAsset, uint256 collateralAmount,
                  address loanAsset, uint256 loanAmount,
                  address terminal) internal {
        Position position = Position({
            borrowAccount: borrowAccount,
            supplyAccount: supplyAccount,
            termSheet: termSheet,
            collateralAsset: collateralAsset,
            collateralAmount: collateralAmount,
            loanAsset: loanAsset,
            loanAmount: loanAmount,
            terminal: terminal
        });
        position.borrowerId = msg.sender;
        position.terminalAddress = terminal;
        position.inputAmount = loanAmount + collateralAmount;

        require(position.liquidationThreshholdAmount < collateralAmount + loanAmount);

        // Check and decrement supply in SA.
        SavingsAccount sa = new SavingsAccount();
        sa.borrowFromSupply(id, amount);

        // Send assets to terminal.
        if (asset == address(0)) {
            payable(terminalAddress).transfer(amount);
        } else {
            require(IERC20(asset).transferFrom(address(this), terminalAddress, amount));
        }

        // Create new position in the Terminal.
        t = ITerminal(terminalAddress);
        require(loanAsset == t.asset); // Require loan asset to be same as terminal asset.
        position.positionId = t.enter(amount);

        positions[position.positionId] = position;
        PositionCreated(position.positionId);
    }

    // Lender fills Requisition.
    function give()

    function exit(bytes32 positionId) public {
        t = ITerminal(terminalAddress);
        uint256 positionValue = t.getPositionValue(positionId);
        // ...
    }

    // Liquidators -> Term Sheets.
    function exitLiquidate(bytes32 positionId) public {
        position = positions[positionId];
        t = ITerminal(terminalAddress);
        t.getPositionValue(positionId);
        require(position.liquidationThreshholdAmount)
        emit PositionLiquidated(uint32, uint256)
    }

    // Take the lender profits from all term sheet positions in a terminal and distribute among lenders.
    // Optionally reward sender.
    function exitProfit() public {

        // Exit profit from terminal position and send to Modulon contract as interface asset.
        t = ITerminal(terminalAddress);
        uint256 profit = t.exitProfit();
        emit ProfitTaken(terminalAddress, profit);

        // Reward the caller. Reduce supplier profits accordingly.
        uint256 reward = profit.mulDiv(profiteerRewardRatio, RATIO_BASE);
        profit -= reward;


        uint256 interst = outstandingInterest(position);
        uint256 supplierProfitShare = profit.mulDiv(profitShareRatio / RATIO_BASE);

        SavingsAccount sa = new SavingsAccount();
        // Distribute profits to lenders proporional to their term sheet supply contribution.
        // Profit is entirely new assets, so goes into ciruclating balance, but does not alter
        // entitlements.
        sa.AddToSuppliedAmount(id, profit);
        // Distribute reward after profit, in the case profiteer has crate set to this Term Sheet.
        sa.initOrAddToCrate(msg.sender, interfaceAssetAddress, reward);
    }

    // Terminals -> Term Sheets.

    // Public helpers.
    function getParameters() public view returns (InstructionsParameters params) {return parameters;}
    function getPositions() public view returns (Positions) {return positions;}
    function getTerminalAddress() public view returns (address) {return terminal;}


    function getLiquidationValueThreshold(bytes32 positionId) public {
        Position position = positions[positionId];
        TermSheet termSheet = termSheets[position.termSheetId];
        Valuator collateralValuator = termSheet.valuators[position.collateralAsset];
        collateralValue = position.collateralAmount * ValuatorUtils.value(collateralValuator);
        return termSheet.maxCollateralizationRatio * collateralValue + outstandingInterest(positionId) + outstandingProfitShare(positionId);
    }

    /* Private helpers */

    function outstandingInterestValue(bytes32 positionId) private returns (uint256) {
        Position position = positions[positionId];
        TermSheet termSheet = termSheets[position.termSheetId];
        Valuator loanValuator = termSheet.valuators[position.loanAsset];
        return (now - position.openTime) * termSheet.interestRate * position.loanAmount * ValuatorUtils.value(loanValuator);
    }

    function outstandingProfitShareValue(bytes32 positionId) private returns (uint256) {
        Position position = positions[positionId];
        TermSheet termSheet = termSheets[position.termSheetId];
        Valuator loanValuator = termSheet.valuators[position.loanAsset];
        loanValue = position.collateralAmount * ValuatorUtils.value(loanValuator);
        loanValueDelta = loanValue - position.initLoanValue
        return loanValueDelta > 0? loanValueDelta * termSheet.profitShareRatio : 0;
    }

    event PositionCreated(uint32);
    event ProfitTaken(address, uint256);
    event PositionLiquidated(uint32, uint256);
    event PositionExited(uint32, uint256);
}
