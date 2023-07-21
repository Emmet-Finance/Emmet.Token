import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import {config as CONFIG} from 'dotenv';
CONFIG();

const accounts = [process.env.SK!]

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  networks: {
    tbsc: {
      url:'https://bsc-testnet.publicnode.com',
      accounts
    },
    bsc:{
      url:'https://bsc.publicnode.com',
      accounts
    }
  }
};

export default config;
