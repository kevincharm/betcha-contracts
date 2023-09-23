import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers'
import { ethers } from 'hardhat'
import {
    BetchaRoundFactory,
    BetchaRoundFactory__factory,
    MockERC20__factory,
} from '../typechain-types'
import { BASE_GNOSIS_SAFE_MASTERCOPY, BASE_GNOSIS_SAFE_PROXY_FACTORY } from '../lib/config'

describe('Betcha', () => {
    let deployer: SignerWithAddress
    let factory: BetchaRoundFactory
    beforeEach(async () => {
        ;[deployer] = await ethers.getSigners()
        factory = await new BetchaRoundFactory__factory(deployer).deploy(
            BASE_GNOSIS_SAFE_PROXY_FACTORY,
            BASE_GNOSIS_SAFE_MASTERCOPY,
        )
    })

    it('runs happy path w/o safe', async () => {
        const wagerToken = await new MockERC20__factory(deployer).deploy('Fake USDC', 'USDFC')
        const wagerTokenAmount = 1_000_000
        const now = Math.floor(Date.now() / 1000)
        const wagerDeadlineAt = now + 60
        const settlementAvailableAt = now + 120
        factory.createRound(
            await wagerToken.getAddress(),
            wagerTokenAmount,
            [deployer.address],
            wagerDeadlineAt,
            settlementAvailableAt,
        )
    })
})
