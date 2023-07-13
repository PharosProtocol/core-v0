# Liquidator
Liquidators define the logic that underpins how a liquidation is executed. They may be instantaneous or across a period of time.

Truly your imagination is the limit here. If you want to build a liquidation system that gives the liquidator 1000 USDC,
mints a crypto dickbutt to the liquidated borrower's wallet, and returns the remaining value as an excessively leveraged
BTC maxi position to the lender, you can! We wouldn't really recommend it, and I am not sure anyone would accept your
offer, but you certainly can do it.

## Implementation notes
- Must be able to handle loan asset == collateral asset type