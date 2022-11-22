const { ethers } = require(`hardhat`);
const { lastNonce, getFromContractStorage } = require('@gazoblock/commonlibrary')


async function main() {

    const [deployer] = await ethers.getSigners();
    let nonce = await lastNonce(deployer.address) -1;
    console.log(`Deployer address: ${deployer.address} nonce: ${nonce}`);

    console.log(`Change router address`);
    const FeeReward = await ethers.getContractFactory(`SwapFeeRewardUpgradeable`);
    const feeReward = await FeeReward.attach(getFromContractStorage(`SwapFeeRewardUpgradeable`))

    await feeReward.setRouter(`0x3a6d8cA21D1CF76F653A67577FA0D27453350dD8`)

}

main().catch((error) => console.error(error) && process.exit(1));
