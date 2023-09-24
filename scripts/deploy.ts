import { ethers, run } from 'hardhat'
import { BetchaRoundFactory__factory, BetchaRound__factory } from '../typechain-types'
import { BASE_GNOSIS_SAFE_MASTERCOPY, BASE_GNOSIS_SAFE_PROXY_FACTORY } from '../lib/config'

async function main() {
    const [deployer] = await ethers.getSigners()
    const masterCopy = await new BetchaRound__factory(deployer)
        .deploy()
        .then((contract) => contract.waitForDeployment())
    const factoryConstructorArgs: Parameters<
        InstanceType<typeof BetchaRoundFactory__factory>['deploy']
    > = [BASE_GNOSIS_SAFE_PROXY_FACTORY, BASE_GNOSIS_SAFE_MASTERCOPY, await masterCopy.getAddress()]
    const factory = await new BetchaRoundFactory__factory(deployer)
        .deploy(...factoryConstructorArgs)
        .then((contract) => contract.waitForDeployment())
    console.log(`Factory deployed to: ${await factory.getAddress()}`)

    // Wait for etherscan to catch up
    await new Promise((resolve) => setTimeout(resolve, 60_000))

    // Verify mastercopy
    await run('verify:verify', {
        address: await masterCopy.getAddress(),
        constructorArguments: [],
    })
    // Verify factory
    await run('verify:verify', {
        address: await factory.getAddress(),
        constructorArguments: factoryConstructorArgs,
    })
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
