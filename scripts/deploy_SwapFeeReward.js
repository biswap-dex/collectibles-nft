const { ethers, upgrades, network } = require(`hardhat`);
const { toBN, lastNonce, getFromContractStorage, setToContractStorage } = require('@gazoblock/commonlibrary');

const RB_SETTER_ROLE = `0xc7c9819f33f023fb575ae9b63a0181942ca5956a309f3641e15d6dc199033e46`;
const routerOwnerAddress = `0xc6af770101da859d680e0829380748cccd8f7984`;
const ownerAddress = `0xBAfEFe87d57d4C5187eD9Bd5fab496B38aBDD5FF`;
const tokensArray = {
    USDT    : '0x55d398326f99059fF775485246999027B3197955',
    WETH    : '0x2170ed0880ac9a755fd29b2688956bd959f933f8',
    BSW     : '0x965F527D9159dCe6288a2219DB51fc6Eef120dD1',
    WBNB    : '0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c',
    BUSD    : `0xe9e7cea3dedca5984780bafc599bd69add087d56`,
    USDC    : `0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d`,
    BTCB    : `0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c`,
    CAKE    : `0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82`,
    DOT     : `0x7083609fce4d1d8dc0c979aab8c869ea2c873402`,
    UNI     : `0xbf5140a22578168fd562dccf235e5d43a02ce9b1`,
    ADA     : `0x3ee2200efb3400fabb9aacf31297cbdd1d435d47`,
    LTC     : `0x4338665cbb7b2485a8855a139b75d5e34ab0db94`,
    XRP     : `0x1d2f0da169ceb9fc7b3144628db156f3f6c60dbe`,
    DOGE    : `0xba2ae424d960c26247dd6c32edc70b295c744c43`,
    LINK    : `0xf8a0bf9cf54bb92f17374d9e9a321e6a111a51bd`,
    DAI     : `0x1af3f329e8be154074d8769d1ffa4ee058b1dbc3`,
    BAKE    : `0xe02df9e3e622debdd69fb838bb799e3f168902c5`,
    FIL     : `0x0d8ce2a99bb6e3b7db580ed848240e4a0f9ae153`,
    XVS     : `0xcf6bb5389c92bdda8a3747ddb454cb7a64626c63`,
    TWT     : `0x4b0f1812e5df2a09796481ff14017e6005508003`,
    BFG     : `0xbb46693ebbea1ac2070e59b4d043b47e2e095f86`,
    TENFI   : `0xd15c444f1199ae72795eba15e8c1db44e47abf62`,
    TRX     : `0x85eac5ac2f758618dfa09bdbe0cf174e7d574d5b`,
    TKO     : `0x9f589e3eabe42ebc94a44727b3f3531c0c877809`,
    REEF    : `0xf21768ccbc73ea5b6fd3c687208a7c2def2d966e`,
    SFP     : `0xd41fdb03ba84762dd66a0af1a6c8540ff1ba5dfb`,
    SXP     : `0x47bead2563dcbf3bf2c9407fea4dc236faba485a`,
    MBOX    : `0x3203c9e46ca618c8c1ce5dc67e7e9d75f5da2377`,
    ZIL     : `0xb86abcb37c3a4b64f74f59301aff131a1becc787`,
    AXS     : `0x715d400f88c167884bbcc41c5fea407ed4d2f8a0`,
    C98     : `0xaec945e04baf28b135fa7c640f624f8d90f1c3a6`,
    SHIB    : `0x2859e4544c4bb03966803b044a93563bd2d0dd4d`,
    FTM     : `0xad29abb318791d579433d831ed122afeaf29dcfe`,
    MATIC   : `0xcc42724c6683b7e57334c4e856f4c9965ed682bd`,
    RACA    : `0x12bb890508c125661e03b09ec06e404bc9289040`,
    SOL     : `0x570a5d26f7765ecb712c0924e4de545b89fd43df`,
    AVAX    : `0x1ce0c2827e2ef14d5c4f29a091d735a204794041`,
    NEAR    : `0x1fa4a73a3f0133f0025378af00236f3abdee5d63`,
    GALA    : `0x7ddee176f665cd201f93eede625770e2fd911990`,
    EOS     : `0x56b6fb708fc5732dec1afc8d8556423a2edccbd6`,
    ATOM    : `0x0eb3a705fc54725037cc9e008bdede697f62f335`,
    ONE     : `0x03ff0ff224f904be3118461335064bb48df47938`,
    TONCOIN : `0x76a797a59ba2c17726896976b7b3747bfd1d220f`,
    APE     : `0x0b079b33b6e72311c6be245f9f660cc385029fc3`,
    ETC     : `0x3d6545b08693dae087e957cb1180ee38b9e3c25e`,
    GMT     : `0x3019bf2a2ef8040c242c9a4c5c4bd4c81678b2a1`,
    DAR     : `0x23ce9e926048273ef83be0a3a8ba9cb6d45cd978`,
    MANA    : `0x26433c8127d9b4e9b71eaa15111df99ea2eeb2f8`,
}
const pairsArray = [
    `0xDA8ceb724A06819c0A5cDb4304ea0cB27F8304cF`,
    `0x8840C6252e2e86e545deFb6da98B2a0E26d8C1BA`,
    `0xaCAac9311b0096E04Dfe96b6D87dec867d3883Dc`,
    `0x1483767E665B3591677Fd49F724bf7430C18Bf83`,
    `0x63b30de1A998e9E64FD58A21F68D323B9BcD8F85`,
    `0xa987f0b7098585c735cD943ee07544a84e923d1D`,
    `0x6216E04cd40DB2c6FBEd64f1B5830A98D3A91740`,
    `0xC7e9d76ba11099AF3F330ff829c5F442d571e057`,
    `0x2b30c317ceDFb554Ec525F85E79538D59970BEb0`,
    `0x46492B26639Df0cda9b2769429845cb991591E0A`,
    `0x3d94d03eb9ea2D4726886aB8Ac9fc0F18355Fd13`,
    `0xe7fbB8bd95322618e925affd84D7eC0E32DC0e57`,
    `0x153dC2eBcB551799b13D4E6Ff84fC34C7AEDf241`,
    `0x8860922Eb2795aB0D57363653Dd7EBf18D7c0A42`,
    `0x412b607f4cBE9CaE77C6F720A701CD60fa0EBD3f`,
    `0x5dc30Bb8D7F02eFEf28f7E637D17Aea13Fa96906`,
    `0x1eF315fa08e0E1B116D97E3dFE0aF292Ed8b7f02`,
    `0x16Fe21c91c426E603977b1C6EcD59Fc510a518C2`,
    `0x5bf6941f029424674bb93A43b79fc46bF4A67c21`,
    `0xe0caab61EE7A12d03B268E1f6A56537aC1b61D13`,
    `0x4c372698eaF2DA2A04dfEaDFE14DB0635fEfdB34`,
    `0x52A499333A7837a72a9750849285E0bb8552dE5A`,
    `0x753C734Dfe05aF28A732C033e26Ea6D369e07662`,
    `0xF1A12EC907B3d87b6De7a9A5C3820566c621f68B`,
    `0x88d483697F8E3FC8f5674F322d3a59ce786aCcD5`,
    `0xf9FAdb9222848Cde36c0C06cF88776DC41937083`,
    `0x16da0c473214717383b7Ef5cdE71c723584f8ac4`,
    `0xDE5e03bC7014D65aF8F9fe8F11FDb5B5b9116F7b`,
    `0xfbbd096A99e95D6808b918A5C0863ed9989EBd41`,
    `0x857f601Df3Eac2f25E25dBd2B33D94bCd6F47d1C`,
    `0xedc3f1edB8811d2aE4aD6666D77521ae817F2ef1`,
    `0x76e1B3B2B15A4Ff61aB3E245d6b98ae808DEe6e1`,
    `0xe41F46AEF7594Cc43FC57edf2b0fDC377900BC4E`,
    `0x19058558Bbc66C2Dd97c5cA8a189d350A34e4423`,
    `0x38fd42c46Cb8Db714034dF920f6663b31Bb63DDe`,
    `0x49859419c83465eeeEdD7b1D30dB99CE58C88Ec3`,
    `0x7bfCd2bda87fd2312A946BD9b68f5Acc6E21595a`,
    `0x3B09e13Ca9189FBD6a196cfE5FbD477C885afBf3`,
    `0x9C3d4Fb14D3A021aee4Fd763506B1F71d509Dc90`,
    `0x3530F7d8D55c93D778e17cbd30bf9eB07b884f35`,
    `0x2f3899fFB9FdCf635132F7bb94c1a3A0F906cc6f`,
    `0xe0E9FDd2F0BcdBcaF55661B6Fa1efc0Ce181504b`,
    `0x4F00ADEED60FCba76e58a5d067b6A4b9Daf8e30f`,
    `0x7683f8349376F297138D3082e236F0E34aF1D1c3`,
    `0x5a36E9659F94F27e4526DDf6Dd8f0c3B3386D7F3`,
    `0xe73fe11863e4C3714EAFDee832a0987b33651f27`,
    `0x923dD5668A0F373B714f8D230425ed7799c5d63D`,
    `0xc2619B94d60223db62991a1DB937D723A2Ed6217`,
    `0x1Cba970a6E06d4BcC0c4717BE677d1A8AA0211DA`,
    `0xeC6158b246EED756f54505571ed29749929019Dd`,
    `0x5843d070F37ef8579CC3903B486DE1FDA80904D0`,
    `0x06Cd679121Ec37B0A2FD673D4976B09d81791856`,
    `0x284F871d6F2D4fE070F1E18c355eF2825e676AA2`,
    `0x1Cba970a6E06d4BcC0c4717BE677d1A8AA0211DA`
]
const percentArray = [
    5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 50, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5
]
const intermediateTokenList = [
    { output: tokensArray.BSW ,     anchor: tokensArray.USDT, intermediate: tokensArray.BSW},
    { output: tokensArray.USDT ,    anchor: tokensArray.BSW,  intermediate: tokensArray.USDT},
    { output: tokensArray.BUSD,     anchor: tokensArray.BSW,  intermediate: tokensArray.USDT},
    { output: tokensArray.BUSD ,    anchor: tokensArray.USDT, intermediate: tokensArray.BUSD},
    { output: tokensArray.WBNB,     anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.WBNB ,    anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.USDC,     anchor: tokensArray.BSW,  intermediate: tokensArray.USDT},
    { output: tokensArray.USDC ,    anchor: tokensArray.USDT, intermediate: tokensArray.USDC},
    { output: tokensArray.WETH,     anchor: tokensArray.BSW,  intermediate: tokensArray.USDT},
    { output: tokensArray.WETH ,    anchor: tokensArray.USDT, intermediate: tokensArray.WETH},
    { output: tokensArray.BTCB,     anchor: tokensArray.BSW,  intermediate: tokensArray.USDT},
    { output: tokensArray.BTCB ,    anchor: tokensArray.USDT, intermediate: tokensArray.BTCB},
    { output: tokensArray.CAKE,     anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.CAKE ,    anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.DOT,      anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.DOT ,     anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.UNI,      anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.UNI ,     anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.ADA,      anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.ADA ,     anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.LTC,      anchor: tokensArray.BSW,  intermediate: tokensArray.USDT},
    { output: tokensArray.LTC ,     anchor: tokensArray.USDT, intermediate: tokensArray.LTC},
    { output: tokensArray.XRP,      anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.XRP ,     anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.DOGE,     anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.DOGE ,    anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.LINK,     anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.LINK ,    anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.DAI,      anchor: tokensArray.BSW,  intermediate: tokensArray.USDT},
    { output: tokensArray.DAI ,     anchor: tokensArray.USDT, intermediate: tokensArray.DAI},
    { output: tokensArray.BAKE,     anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.BAKE ,    anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.FIL,      anchor: tokensArray.BSW,  intermediate: tokensArray.USDT},
    { output: tokensArray.FIL ,     anchor: tokensArray.USDT, intermediate: tokensArray.FIL},
    { output: tokensArray.XVS,      anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.XVS ,     anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.TWT,      anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.TWT ,     anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.BFG,      anchor: tokensArray.BSW,  intermediate: tokensArray.BFG},
    { output: tokensArray.BFG ,     anchor: tokensArray.USDT, intermediate: tokensArray.BSW},
    { output: tokensArray.TENFI,    anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.TENFI ,   anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.TRX,      anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.TRX ,     anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.TKO,      anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.TKO ,     anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.REEF,     anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.REEF ,    anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.SFP,      anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.SFP ,     anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.SXP,      anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.SXP ,     anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.MBOX,     anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.MBOX ,    anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.ZIL,      anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.ZIL ,     anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.AXS,      anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.AXS ,     anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.C98,      anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.C98 ,     anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.SHIB,     anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.SHIB ,    anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.FTM,      anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.FTM ,     anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.MATIC,    anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.MATIC ,   anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.RACA,     anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.RACA ,    anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.SOL,      anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.SOL ,     anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.AVAX,     anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.AVAX ,    anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.NEAR,     anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.NEAR ,    anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.GALA,     anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.GALA ,    anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.EOS,      anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.EOS ,     anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.ATOM,     anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.ATOM ,    anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.ONE,      anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.ONE ,     anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.TONCOIN,  anchor: tokensArray.BSW,  intermediate: tokensArray.USDT},
    { output: tokensArray.TONCOIN , anchor: tokensArray.USDT, intermediate: tokensArray.TONCOIN},
    { output: tokensArray.APE,      anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.APE ,     anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.ETC,      anchor: tokensArray.BSW,  intermediate: tokensArray.WBNB},
    { output: tokensArray.ETC ,     anchor: tokensArray.USDT, intermediate: tokensArray.WBNB},
    { output: tokensArray.GMT,      anchor: tokensArray.BSW,  intermediate: tokensArray.USDT},
    { output: tokensArray.GMT ,     anchor: tokensArray.USDT, intermediate: tokensArray.GMT},
    { output: tokensArray.DAR,      anchor: tokensArray.BSW,  intermediate: tokensArray.USDT},
    { output: tokensArray.DAR ,     anchor: tokensArray.USDT, intermediate: tokensArray.DAR},
    { output: tokensArray.MANA,     anchor: tokensArray.BSW,  intermediate: tokensArray.USDT},
    { output: tokensArray.MANA ,    anchor: tokensArray.USDT, intermediate: tokensArray.MANA},
]

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

    const routerDeployer = network.name === `localhost` ? await impersonateAccount(routerOwnerAddress) : (await ethers.getSigners())[0];

    const Router = await ethers.getContractFactory(`BiswapRouter02`, routerDeployer);
    // const router = await Router.attach(`0x3a6d8cA21D1CF76F653A67577FA0D27453350dD8`);
    const router = await Router.attach(`0x140ECe3E81EA384372e89317189E94bF7f30603f`);

    console.log(`Deploy swapFeeReward upgradable`);
    const FeeReward = await ethers.getContractFactory(`SwapFeeRewardUpgradeable`, deployer);
    const feeReward = await upgrades.deployProxy(FeeReward, [
        router.address, //_router
        tokensArray.BSW, //_bswToken
        `0x1c75c382E3195a0FCe4cE9def994932E0a805974`, //_Oracle
        `0xD4220B0B196824C2F548a34C47D81737b0F6B5D6`, //biswapNFTs
        getFromContractStorage(`BiswapCollectiblesNFT`).address, //_collectiblesNFT
        tokensArray.BSW, //_targetToken
        tokensArray.USDT, //_targetRBToken
        [                                             //_cashbackPercent
            {
                percent: 250,
                monthlyLimit: toBN(10000)
            },
            {
                percent: 500,
                monthlyLimit: toBN(20000)
            },
            {
                percent: 750,
                monthlyLimit: toBN(30000)
            },
            {
                percent: 1000,
                monthlyLimit: toBN(40000)
            },
            {
                percent: 1500,
                monthlyLimit: toBN(50000)
            },
        ], //_cashbackPercent
        `0x23567C7299702018B133ad63cE28685788ff3f67`, //market contract
        `0xE7D045e662BBBcC5c4AD3890f32211E0d36f4720` //auction contract
    ])

    await feeReward.deployed();
    console.log(`feeReward deployed to ${feeReward.address}`);

    setToContractStorage(feeReward, `SwapFeeRewardUpgradeable`);

    if(routerDeployer.address.toLowerCase() === routerOwnerAddress.toLowerCase()){
        console.log(`set feeReward to router`);
        let nonceRouterOwner = await lastNonce(routerDeployer.address) - 1;
        await router.setSwapFeeReward(feeReward.address, {nonce: ++nonceRouterOwner, gasLimit: 1e6});
    } else {
        console.log(`Change fee reward on ${router.address} router to ${feeReward.address}!!!`);
    }

    let nonce = await lastNonce(deployer.address) - 1;
    const res = [];
    console.log(`Set intermediate tokens`);
    res.push(await feeReward.setIntermediateToken(intermediateTokenList, {nonce: ++nonce, gasLimit: 3e6}));

    console.log(`Set pairs fee return`);
    res.push(await feeReward.setPairs(percentArray, pairsArray, {nonce: ++nonce, gasLimit: 3e6}));


    console.log(`set feeReward RB_SETTER_ROLE at biswapNFT`);
    const BiswapNFT = await ethers.getContractFactory(`BiswapNFT`,deployer);
    const biswapNFT = BiswapNFT.attach(`0xD4220B0B196824C2F548a34C47D81737b0F6B5D6`);
    res.push(await biswapNFT.grantRole(RB_SETTER_ROLE, feeReward.address, {nonce: ++nonce, gasLimit: 3e6}));


    console.log(`Set fee return to market and auction`);
    const marketContract = new ethers.Contract(
        `0x23567C7299702018B133ad63cE28685788ff3f67`,
        [`function addNftForAccrualRB(address)`, `function setFeeRewardRB(address)`],
        deployer
    )
    const auctionContract = new ethers.Contract(
        `0xE7D045e662BBBcC5c4AD3890f32211E0d36f4720`,
        [`function addNftForAccrualRB(address)`, `function updateSettings(uint256,uint256,uint256,uint256,uint256,uint256,address,address)`],
        deployer
    )

    res.push(await marketContract.addNftForAccrualRB(getFromContractStorage(`BiswapCollectiblesNFT`).address, {nonce: ++nonce, gasLimit: 1e6}));
    res.push(await marketContract.setFeeRewardRB(feeReward.address, {nonce: ++nonce}));

    res.push(await auctionContract.addNftForAccrualRB(getFromContractStorage(`BiswapCollectiblesNFT`).address, {nonce: ++nonce, gasLimit: 1e6}));

    res.push(await auctionContract[`updateSettings(uint256,uint256,uint256,uint256,uint256,uint256,address,address)`](
        21600, // extendEndTimestamp_
        600, //prolongationTime_
        86400, //minAuctionDuration_
        10000, //rateBase_
        500, //bidderIncentiveRate_
        1000, //bidIncrRate_
        `0x863e9e0c64c18ef17dbb7a479499ea039c6b5ad3`, //treasuryAddress_
        feeReward.address, //_feeRewardRB
        {nonce: ++nonce, gasLimit: 1e6}
    ));

    if(((await Promise.all(res.map(r => r.wait()))).map(r => r.status)).every(elem => elem === 1)) console.log(`All Tx done`);
}

main().catch((error) => console.error(error) && process.exit(1));
