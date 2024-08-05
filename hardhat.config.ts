import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-deploy";
import "hardhat-gas-reporter";
import "hardhat-abi-exporter";
import "@nomiclabs/hardhat-solhint";
import { config as dotConfig } from "dotenv";
dotConfig({});

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: { enabled: true, runs: 200 },
    },
  },
  namedAccounts: {
    deployer: 0,
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
    gasPrice: 60,
  },
  abiExporter: {
    path: "./abis",
    runOnCompile: true,
    clear: true,
  },
  networks: {
    goerli: {
      url: "https://rpc.ankr.com/eth_goerli",
      accounts: [process.env.PRIVATE_KEY || ""],
    },
    mumbai: {
      url: "https://rpc.ankr.com/polygon_mumbai",
      accounts: [process.env.PRIVATE_KEY || ""],
      allowUnlimitedContractSize: true,
    },
    polygon: {
      url: "https://rpc.ankr.com/polygon",
      accounts: [process.env.PRIVATE_KEY || ""],
    },
    bsc: {
      url: "https://rpc.ankr.com/bsc",
      accounts: [process.env.PRIVATE_KEY || ""],
    },
    ethereum: {
      url: "https://rpc.ankr.com/eth",
      accounts: [process.env.PRIVATE_KEY || ""],
    },
    arbitrum: {
      url: "https://rpc.ankr.com/arbitrum",
      accounts: [process.env.PRIVATE_KEY || ""],
    },
    local: {
      url: "http://127.0.0.1:8545",
      accounts: [
        "0xf214f2b2cd398c806f84e317254e0f0b801d0643303237d97a22a48e01628897" ||
          "",
      ],
    },
  },
};

export default config;
