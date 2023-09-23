import { ethers } from 'hardhat'
import { BetchaRoundFactory__factory } from '../typechain-types'
import { BASE_GNOSIS_SAFE_MASTERCOPY, BASE_GNOSIS_SAFE_PROXY_FACTORY } from '../lib/config'

async function main() {
    const [deployer] = await ethers.getSigners()
    const factory = await new BetchaRoundFactory__factory(deployer).deploy(
        BASE_GNOSIS_SAFE_PROXY_FACTORY,
        BASE_GNOSIS_SAFE_MASTERCOPY,
    )
    await factory.waitForDeployment()
    console.log(`Factory deployed to: ${await factory.getAddress()}`)
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
