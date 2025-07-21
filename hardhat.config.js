require("@nomicfoundation/hardhat-toolbox");
require("hardhat-faucet");


// Replace this private key with your Sepolia account private key
// To export your private key from Coinbase Wallet, go to
// Settings > Developer Settings > Show private key
// To export your private key from Metamask, open Metamask and
// go to Account Details > Export Private Key
// Beware: NEVER put real Ether into testing accounts
const PRIVATE_KEY = "";

module.exports = {
  solidity: "0.8.19",
  defaultNetwork: "hardhat",
  networks: {
    bsctest: {
      url: 'https://data-seed-prebsc-1-s1.binance.org:8545/',
      accounts: [PRIVATE_KEY]
    },
    bsc: {
      url: 'https://nodes.pancakeswap.info',
      accounts: [PRIVATE_KEY]
    },
    bbfork: {
      url: 'https://rpc.buildbear.io/equivalent-han-solo-113f85af',
      accounts: [PRIVATE_KEY]
    }
  }
};