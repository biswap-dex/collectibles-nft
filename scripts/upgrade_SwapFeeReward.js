const { ethers, upgrades, network } = require(`hardhat`);
const { toBN, lastNonce, getFromContractStorage, setToContractStorage } = require('@gazoblock/commonlibrary');

const ownerAddress = `0xBAfEFe87d57d4C5187eD9Bd5fab496B38aBDD5FF`;
swapFeeRewardAddress = '0x785E76678e04aD2aC481fcdbE9064b00Dd8651e3'

getImplementationAddress = async (
    proxyAddress,
    implSlotAddress = '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc'
) => {
    const implHex = await ethers.provider.getStorageAt(proxyAddress,implSlotAddress)
    return ethers.utils.hexStripZeros(implHex)
}

async function impersonateAccount(acctAddress) {
    await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [acctAddress],
    });
    return await ethers.getSigner(acctAddress);
}

async function main() {
    const deployer = network.name === `localhost` ? await impersonateAccount(ownerAddress) : (await ethers.getSigners())[0];
    console.log(`Deployer address: ${deployer.address}`);

    const FeeReward = await ethers.getContractFactory(`SwapFeeRewardUpgradeable`, deployer);
    // await upgrades.forceImport(swapFeeRewardAddress, FeeReward);
    const feeReward = await upgrades.upgradeProxy(swapFeeRewardAddress, FeeReward)
    await feeReward.deployed();
    console.log(`feeReward upgraded new impl address ${await getImplementationAddress(swapFeeRewardAddress)}`);


    // const res = [];
    // let nonce = await lastNonce(deployer.address) - 1;
    //
    // console.log(`disable RB on market and auction`);
    // const marketContract = new ethers.Contract(
    //     `0x23567C7299702018B133ad63cE28685788ff3f67`,
    //     [`function addNftForAccrualRB(address)`, `function setFeeRewardRB(address)`, `function disableRBFeeReward()`],
    //     deployer
    // )
    // const auctionContract = new ethers.Contract(
    //     `0xE7D045e662BBBcC5c4AD3890f32211E0d36f4720`,
    //     [`function addNftForAccrualRB(address)`, `function updateSettings(uint256,uint256,uint256,uint256,uint256,uint256,address,address)`, `function disableRBFeeReward()`],
    //     deployer
    // )
    //
    // res.push(await marketContract.disableRBFeeReward({nonce: ++nonce}));
    // res.push(await auctionContract.disableRBFeeReward({nonce: ++nonce}));
    // if(((await Promise.all(res.map(r => r.wait()))).map(r => r.status)).every(elem => elem === 1)) console.log(`All Tx done`);
}

main().catch((error) => console.error(error) && process.exit(1));
