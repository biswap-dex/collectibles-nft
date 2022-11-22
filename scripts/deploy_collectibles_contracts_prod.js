const { ethers, upgrades, network } = require(`hardhat`);
const { toBN, lastNonce, setToContractStorage } = require('@gazoblock/commonlibrary')

const contractsAddresses = {
    biswapNFT: `0xD4220B0B196824C2F548a34C47D81737b0F6B5D6`,
    squidPlayerNFT: `0xb00ED7E3671Af2675c551a1C26Ffdcc5b425359b`,
    squidBusNFT: `0x6d57712416eD4890e114A37E2D84AB8f9CEe4752`,
    OldSwapFeeReward: `0x04eFD76283A70334C72BB4015e90D034B9F3d245`,
    holderPool: `0xa4b20183039b2F9881621C3A03732fBF0bfdff10`
}

const ownerAddress = `0xBAfEFe87d57d4C5187eD9Bd5fab496B38aBDD5FF`
const COLLECTIBLES_CHANGER = `0xe9f6fbd6efc552cacd6e794f61a41d5c6f1d04fe824227f3b613d60536448136`
const TOKEN_MINTER_ROLE = `0x262c70cb68844873654dc54487b634cb00850c1e13c785cd0d96a2b89b829472`


async function impersonateAccount(acctAddress) {
    await network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [acctAddress],
    });
    return await ethers.getSigner(acctAddress);
}

const collectiblesNFTParams = [
    "https://biswap.org/back/collectibles-nft/metadata/",//string memory baseURI,
    "BiswapCollectibles", //         string memory name_,
    "BSC"//         string memory symbol_
]

async function main(){
    let deployer = network.name === `localhost` ? await impersonateAccount(ownerAddress) : (await ethers.getSigners())[0];
    if(deployer.address.toLowerCase() !== ownerAddress.toLowerCase()){
        console.log(`Change deployer address. Current deployer: ${deployer.address}. Owner: ${ownerAddress}`);
        return;
    }
    console.log(`Deployer address: ${deployer.address}`);

    const factories = {
        BiswapNFT: await ethers.getContractFactory(`BiswapNFT`, deployer),
        SquidPlayerNFT: await ethers.getContractFactory(`SquidPlayerNFT`, deployer),
        SquidBusNFT: await ethers.getContractFactory(`SquidBusNFT`, deployer),
        BiswapCollectibles: await ethers.getContractFactory(`BiswapCollectiblesNFT`, deployer),
        CollectiblesChanger: await ethers.getContractFactory(`CollectiblesChanger`, deployer)
    }

    console.log(`Deploy NFT Collectibles`);
    const biswapCollectibles = await upgrades.deployProxy(factories.BiswapCollectibles, collectiblesNFTParams);
    await biswapCollectibles.deployed();
    console.log(`Done`);

    console.log(`Deploy NFT Changer`);
    const collectiblesChangerParams = [
        toBN(500),//        uint _minRequirementsHolderPool,
        [[ //Level 1
            {
                rb: toBN(500),
                se: toBN(50000),
                busCap: 10,
                quantityAvailable: 30,
                quantitySold: 0
            },
            {
                rb: toBN(1000),
                se: toBN(100000),
                busCap: 10,
                quantityAvailable: 30,
                quantitySold: 0
            },
            {
                rb: toBN(1500),
                se: toBN(150000),
                busCap: 10,
                quantityAvailable: 25,
                quantitySold: 0
            },
            {
                rb: toBN(1800),
                se: toBN(180000),
                busCap: 10,
                quantityAvailable: 25,
                quantitySold: 0
            },
            {
                rb: toBN(2000),
                se: toBN(200000),
                busCap: 10,
                quantityAvailable: 20,
                quantitySold: 0
            }
        ],
            [ //Level 2
                {
                    rb: toBN(3000),
                    se: toBN(300000),
                    busCap: 25,
                    quantityAvailable: 25,
                    quantitySold: 0
                },
                {
                    rb: toBN(3500),
                    se: toBN(350000),
                    busCap: 25,
                    quantityAvailable: 25,
                    quantitySold: 0
                },
                {
                    rb: toBN(4000),
                    se: toBN(400000),
                    busCap: 25,
                    quantityAvailable: 20,
                    quantitySold: 0
                },
                {
                    rb: toBN(5000),
                    se: toBN(500000),
                    busCap: 25,
                    quantityAvailable: 20,
                    quantitySold: 0
                },
                {
                    rb: toBN(6000),
                    se: toBN(600000),
                    busCap: 25,
                    quantityAvailable: 10,
                    quantitySold: 0
                }
            ],
            [ //Level 3
                {
                    rb: toBN(7000),
                    se: toBN(700000),
                    busCap: 50,
                    quantityAvailable: 10,
                    quantitySold: 0
                },
                {
                    rb: toBN(8000),
                    se: toBN(800000),
                    busCap: 50,
                    quantityAvailable: 10,
                    quantitySold: 0
                },
                {
                    rb: toBN(9000),
                    se: toBN(900000),
                    busCap: 50,
                    quantityAvailable: 10,
                    quantitySold: 0
                },
                {
                    rb: toBN(10000),
                    se: toBN(1000000),
                    busCap: 50,
                    quantityAvailable: 10,
                    quantitySold: 0
                },
                {
                    rb: toBN(11000),
                    se: toBN(1100000),
                    busCap: 50,
                    quantityAvailable: 10,
                    quantitySold: 0
                }
            ],
            [ //Level 4
                {
                    rb: toBN(20000),
                    se: toBN(2000000),
                    busCap: 75,
                    quantityAvailable: 3,
                    quantitySold: 0
                },
                {
                    rb: toBN(30000),
                    se: toBN(3000000),
                    busCap: 75,
                    quantityAvailable: 3,
                    quantitySold: 0
                },
                {
                    rb: toBN(40000),
                    se: toBN(4000000),
                    busCap: 75,
                    quantityAvailable: 3,
                    quantitySold: 0
                },
                {
                    rb: toBN(50000),
                    se: toBN(5000000),
                    busCap: 75,
                    quantityAvailable: 3,
                    quantitySold: 0
                },
                {
                    rb: toBN(60000),
                    se: toBN(6000000),
                    busCap: 75,
                    quantityAvailable: 3,
                    quantitySold: 0
                }
            ],
            [ //Level 5
                {
                    rb: toBN(80000),
                    se: toBN(8000000),
                    busCap: 100,
                    quantityAvailable: 1,
                    quantitySold: 0
                },
                {
                    rb: toBN(90000),
                    se: toBN(9000000),
                    busCap: 100,
                    quantityAvailable: 1,
                    quantitySold: 0
                },
                {
                    rb: toBN(100000),
                    se: toBN(10000000),
                    busCap: 100,
                    quantityAvailable: 1,
                    quantitySold: 0
                },
                {
                    rb: toBN(110000),
                    se: toBN(11000000),
                    busCap: 100,
                    quantityAvailable: 1,
                    quantitySold: 0
                },
                {
                    rb: toBN(120000),
                    se: toBN(12000000),
                    busCap: 100,
                    quantityAvailable: 1,
                    quantitySold: 0
                }
            ]
        ],
        contractsAddresses.holderPool, //IAutoBsw _holderPool
        contractsAddresses.squidPlayerNFT, //ISquidPlayerNFT _squidPlayerNFT,
        contractsAddresses.squidBusNFT, //ISquidBusNFT _squidBusNFT,
        contractsAddresses.biswapNFT, //IBiswapNFT _robiNFT,
        biswapCollectibles.address //IBiswapCollectiblesNFT _biswapCollectibles
    ]
    const collectiblesChanger = await upgrades.deployProxy(factories.CollectiblesChanger, collectiblesChangerParams)
    await collectiblesChanger.deployed();
    console.log(`Done`);

    const contracts = {
        biswapNFT: await factories.BiswapNFT.attach(contractsAddresses.biswapNFT),
        squidPlayerNFT: await factories.SquidPlayerNFT.attach(contractsAddresses.squidPlayerNFT),
        squidBusNFT: await factories.SquidBusNFT.attach(contractsAddresses.squidBusNFT),
        biswapCollectibles,
        collectiblesChanger
    }

    console.log(`write contracts addresses`);
    setToContractStorage(contracts.collectiblesChanger,`CollectiblesChanger`)
    setToContractStorage(contracts.biswapCollectibles,`BiswapCollectiblesNFT`)

    let nonce = await lastNonce(deployer.address) - 1;
    console.log(`set roles`);
    const res = [];
    res.push(await contracts.biswapNFT.grantRole(COLLECTIBLES_CHANGER, contracts.collectiblesChanger.address, {nonce: ++nonce, gasLimit: 1e6}));
    res.push(await contracts.squidPlayerNFT.grantRole(COLLECTIBLES_CHANGER, contracts.collectiblesChanger.address, {nonce: ++nonce, gasLimit: 1e6}));
    res.push(await contracts.squidBusNFT.grantRole(COLLECTIBLES_CHANGER, contracts.collectiblesChanger.address, {nonce: ++nonce, gasLimit: 1e6}));
    res.push(await contracts.biswapCollectibles.grantRole(TOKEN_MINTER_ROLE, contracts.collectiblesChanger.address, {nonce: ++nonce, gasLimit: 1e6}));

    console.log(`Mint test Robi`);
    const testWallet = `0x04F2DdF4FA327323202a9B8714a173D7Af0fE6a0`
    res.push(await contracts.biswapNFT.launchpadMint(testWallet, 3, toBN(500), {nonce: ++nonce, gasLimit: 1e6}))

    if(((await Promise.all(res.map(r => r.wait()))).map(r => r.status)).every(elem => elem === 1)) console.log(`All Tx done`);
}

main().catch(error => console.error(error) && process.exit(1))
