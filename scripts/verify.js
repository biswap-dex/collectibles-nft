const hre = require('hardhat');
const { ethers } = require(`hardhat`);


const contractAddresses = [
    // `0x85311eCaaC316fd1342c163171e19eF94C00F027`,
    // `0x6650eD9411187b808A526e5fEF6F0DFB0b7591E7`
    `0x785E76678e04aD2aC481fcdbE9064b00Dd8651e3`

]

async function getImplementationAddress(proxyAddress) {
    const implHex = await ethers.provider.getStorageAt(
        proxyAddress,
        "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc"
    );
    return ethers.utils.hexStripZeros(implHex);
}

async function main() {
    console.log(`Get implementation addresses`);
    let implAddresses = [];
    for(let i in contractAddresses){
        implAddresses.push(await getImplementationAddress(contractAddresses[i]));
    }
    console.log(implAddresses);

    for(let i in implAddresses){
        console.log(`Verify ${implAddresses[i]} contract`);
        let res = await hre.run("verify:verify", {
            address: `0x095cfb72598d498456b7650178d47f490eb587ea`,//implAddresses[i],
            constructorArguments: [],
            optimizationFlag: true
        })
        console.log(res)
    }

}

main().catch(error => console.error(error) && process.exit(1))
