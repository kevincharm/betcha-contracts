import { ethers } from 'hardhat'
import { BetchaRound__factory } from '../typechain-types'

async function main() {
    const [deployer] = await ethers.getSigners()
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
