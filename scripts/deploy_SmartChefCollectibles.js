const { ethers, network } = require(`hardhat`);
const {Bignumber} = require(`ethers`);
const fs = require("fs");

const toBN = (n, power = 18) => ethers.BigNumber.from(10).pow(power).mul(n)

const reward1TokenAddress = `0x965F527D9159dCe6288a2219DB51fc6Eef120dD1` //BSW
const reward2TokenAddress = `0xbb46693ebbea1ac2070e59b4d043b47e2e095f86` //BFG

const pools = [
    {
        token: reward1TokenAddress,
        rewardPerBlock: new Bignumber.from(`14467592592592592`) // BSW per block
    },
    {
        token: reward2TokenAddress,
        rewardPerBlock: new Bignumber.from(`230034722222222222`)//BFG per block
    },
]

const limits = [
    toBN(100),
    toBN(500),
    toBN(1000),
    toBN(2500),
    toBN(5000)
]

async function main() {
    //IERC20 _stakeToken, uint _stakingEndBlock, IAutoBSW _autoBSW, uint _holderPoolMinAmount, IBiswapCollectiblesNFT _biswapCollectiblesNFT
    const _stakeToken = reward1TokenAddress; //Stake token BSW
    const _stakingEndBlock = (await ethers.provider.getBlock('latest')).number + 3456000; //Staking end block
    const _biswapCollectiblesNFTAddress = `0x6650eD9411187b808A526e5fEF6F0DFB0b7591E7`

    let [deployer] = await ethers.getSigners();

    let nonce = await network.provider.send('eth_getTransactionCount', [deployer.address, 'latest']) - 1;
    console.log(`Deployer address: ${deployer.address} nonce ${nonce}`);

    console.log("Start deploy");
    const SmartChef = await ethers.getContractFactory(`SmartChefNFTCollectibles`);
    const BiswapCollectiblesNFT = await ethers.getContractFactory(`BiswapCollectiblesNFT`);
    const biswapCollectiblesNFT = await BiswapCollectiblesNFT.attach(_biswapCollectiblesNFTAddress);
    //IERC20 _stakeToken, uint _stakingEndBlock, IBiswapCollectiblesNFT _biswapCollectiblesNFT, uint[] memory _limits
    const smartChef = await SmartChef.deploy(
        _stakeToken,
        _stakingEndBlock,
        _biswapCollectiblesNFTAddress,
        limits,
        {nonce: ++nonce});
    await smartChef.deployed();


    console.log(`SmartChef deployed to ${smartChef.address}`);

    console.log(`Add smartChef address to NFT Hooks`);
    await biswapCollectiblesNFT.setTransferHookAddresses(smartChef.address, {gasLimit: 1e6, nonce: ++nonce});

    console.log(`initializing reward tokens`)

    for(let item of pools){
        await smartChef.addNewTokenReward(item.token, 0, item.rewardPerBlock, {gasLimit: 1e6, nonce: ++nonce})
        console.log(`\t- ${item.token} rewardPerBlock ${item.rewardPerBlock.toString()} done`)
    }

    const contractsAddresses = {
        deployerAddress: deployer.address,
        chainId: ethers.provider.network.chainId,
        deployTime: new Date().toLocaleString(),
        smartChef: smartChef.address
    };
    fs.writeFileSync(
        "deployAddressSmartChefCollectibles.json",
        JSON.stringify(contractsAddresses, null, 4)
    );
    console.log(contractsAddresses);
}

main().catch((error) => console.error(error) && process.exit(1));
