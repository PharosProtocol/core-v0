require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-foundry");


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {

  networks: {
    hardhat: {
      forking: {
        url: "https://eth-mainnet.g.alchemy.com/v2/FmZnPJ-foxmzbijvOo6wY-B-uIkaXc4O",
        blockNumber: 18224300 // Replace with the block number you want to fork from
      },
    },
  },

  solidity: "0.8.19",
};
