require("dotenv").config();
require("@nomicfoundation/hardhat-ethers");

const { RPC_URL, DEPLOYER_PRIVATE_KEY } = process.env;

module.exports = {
  solidity: "0.8.24",
  networks: {
    sepolia: {
      url: RPC_URL || "https://sepolia-rpc.example.invalid",
      accounts: /^0x[0-9a-fA-F]{64}$/.test(DEPLOYER_PRIVATE_KEY || "") ? [DEPLOYER_PRIVATE_KEY] : [],
      chainId: 11155111,
    },
  },
};
