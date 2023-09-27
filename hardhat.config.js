require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-foundry");


/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {

  networks: {
    hardhat: {
      forking: {
        url: "https://eth-mainnet.g.alchemy.com/v2/6A5kUZ-khxTNaL68Py0piwkfpCS71L80",
        blockNumber: 18224300 // Replace with the block number you want to fork from
      },
    },
  },

  solidity: "0.8.19",
};
