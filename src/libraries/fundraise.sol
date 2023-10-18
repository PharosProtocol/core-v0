// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/AggregatorV2V3Interface.sol";

interface IOracle {
    function getOpenPrice(bytes calldata data, string calldata key) external view returns (uint256);
}

contract PharosSale {
    address public owner;
    IERC20 public phrs;
    IERC20 public usdc;
    IERC20 public bean;

    AggregatorV3Interface public usdcPriceFeed;
    AggregatorV3Interface public ethPriceFeed;
    IOracle public beanOracle;

    uint256 public phrsUsdPrice;  // Fixed rate for PHRS in USD

    constructor(address _phrs, address _usdc, address _bean, uint256 _phrsUsdPrice) {
        owner = msg.sender;
        phrs = IERC20(_phrs);
        usdc = IERC20(_usdc);
        bean = IERC20(_bean);
        phrsUsdPrice = _phrsUsdPrice;

        // Chainlink price feed addresses for Mainnet
        usdcPriceFeed = AggregatorV3Interface(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);  // USDC/USD
        ethPriceFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);   // ETH/USD
        beanOracle = IOracle(0xB467BB2D164283a38eaAe615DD8e8Ecdbd1C89e9);  // Bean Oracle
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    function getLatestUsdcPrice() public view returns (uint256) {
        (, int price,,,) = usdcPriceFeed.latestRoundData();
        return uint256(price) * 1e10;  // Normalize to 18 decimals
    }

    function getLatestEthPrice() public view returns (uint256) {
        (, int price,,,) = ethPriceFeed.latestRoundData();
        return uint256(price) * 1e10;  // Normalize to 18 decimals
    }

    function getLatestBeanPrice() public view returns (uint256) {
        return beanOracle.getOpenPrice(abi.encode(1), "");
    }

    function buyWithUsdc(uint256 usdcAmount) external {
        uint256 phrsAmount = (usdcAmount * 1e18 * 1e18) / (getLatestUsdcPrice() * phrsUsdPrice);  // No changes needed as USDC is 6 decimals and we've normalized the price to 18 decimals
        require(phrs.balanceOf(address(this)) >= phrsAmount, "Not enough PHRS in contract");

        usdc.transferFrom(msg.sender, address(this), usdcAmount);
        phrs.transfer(msg.sender, phrsAmount);
    }

    function buyWithBean(uint256 beanAmount) external {
        uint256 phrsAmount = (beanAmount * 1e18 * 1e18) / (getLatestBeanPrice() * phrsUsdPrice);  // No changes needed as Bean and PHRS are both 18 decimals
        require(phrs.balanceOf(address(this)) >= phrsAmount, "Not enough PHRS in contract");

        bean.transferFrom(msg.sender, address(this), beanAmount);
        phrs.transfer(msg.sender, phrsAmount);
    }

    function buyWithEth() external payable {
        uint256 phrsAmount = (msg.value * 1e18 * 1e18) / (getLatestEthPrice() * phrsUsdPrice);  // No changes needed as ETH is 18 decimals and we've normalized the price to 18 decimals
        require(phrs.balanceOf(address(this)) >= phrsAmount, "Not enough PHRS in contract");

        phrs.transfer(msg.sender, phrsAmount);
    }

    function withdrawTokens(IERC20 token) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        token.transfer(owner, balance);
    }

    function withdrawEth() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        payable(owner).transfer(balance);
    }
}
