

// hardhat.config.js
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");
require("solidity-coverage");

const PRIVATE_KEY = process.env.PRIVATE_KEY;
const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY;
const MUMBAI_URL = process.env.MUMBAI_URL || "https://rpc-mumbai.matic.today";

module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    mumbai: {
      url: MUMBAI_URL,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      gasPrice: 35000000000,
    },
    polygon: {
      url: "https://polygon-rpc.com",
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      gasPrice: 35000000000,
    }
  },
  etherscan: {
    apiKey: POLYGONSCAN_API_KEY
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  }
};


