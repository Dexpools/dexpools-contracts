require('dotenv').config({path: './.env'});
require("@nomiclabs/hardhat-waffle")
// require("@nomiclabs/hardhat-etherscan")
require('metis-sourcecode-verify')
require('@openzeppelin/hardhat-upgrades')
require('hardhat-contract-sizer')
require('solidity-coverage')
require("hardhat-watcher")
require('hardhat-abi-exporter');


module.exports = {
  abiExporter: {
    path: "./abis",
    clear: true,
    flat: true,
    // pretty: true,
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true
    },
    ethereum: {
      url: "https://mainnet.infura.io/v3/149e969a221349be9b2857c1cb9090ef",
      chainId: 1,
      accounts: [`${process.env.ETHEREUM_MAINNET_KEY}`]
    },
    metis_main: {
      url: "https://andromeda.metis.io/?owner=1088",
      chainId: 1088,
      accounts: [`${process.env.METIS_MAINNET_KEY}`]
    },
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
  },
  solidity: {
    version: "0.8.9",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  mocha: {
    timeout: 360000
  },
  etherscan: {
    apiKey:  'QBBAP13HDC5CHXE3HEVRA1KVQ46JRXX6YR' //etherscan_api_key
  },
  watcher: {
    compile: {
      tasks: ["compile"],
      files: ["./contracts"],
      verbose: true,
    },
  },
}
