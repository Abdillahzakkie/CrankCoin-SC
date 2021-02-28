const { networks } = require("../truffle-config");

const CrankCoin = artifacts.require('CrankCoin');


module.exports = async (deployer, accounts, networks) => {
    await deployer.deploy(CrankCoin);
    console.log(`CrankCoin address: ${CrankCoin.address}`);
}