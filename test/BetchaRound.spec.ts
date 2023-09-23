import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers'
import { time } from '@nomicfoundation/hardhat-network-helpers'
import { ethers } from 'hardhat'
import {
    BetchaRound,
    BetchaRoundFactory,
    BetchaRoundFactory__factory,
    BetchaRound__factory,
    MockERC20__factory,
} from '../typechain-types'
import { BASE_GNOSIS_SAFE_MASTERCOPY, BASE_GNOSIS_SAFE_PROXY_FACTORY } from '../lib/config'
import { expect } from 'chai'

describe('Betcha', () => {
    let deployer: SignerWithAddress
    let bob: SignerWithAddress
    let alice: SignerWithAddress
    let factory: BetchaRoundFactory
    beforeEach(async () => {
        ;[deployer, bob, alice] = await ethers.getSigners()
        factory = await new BetchaRoundFactory__factory(deployer).deploy(
            BASE_GNOSIS_SAFE_PROXY_FACTORY,
            BASE_GNOSIS_SAFE_MASTERCOPY,
        )
    })

    it('runs happy path w/o safe', async () => {
        const wagerToken = await new MockERC20__factory(deployer).deploy('Fake USDC', 'USDFC')
        const wagerTokenAmount = 1_000_000
        await wagerToken.mint(bob.address, 1_000_000_000)
        await wagerToken.mint(alice.address, 1_000_000_000)
        const now = Math.floor(Date.now() / 1000)
        const wagerDeadlineAt = now + 60
        const settlementAvailableAt = now + 120
        const metadataURI = 'ipfs://blabla'
        const tx = await factory
            .createRound(
                await wagerToken.getAddress(),
                wagerTokenAmount,
                [deployer.address],
                wagerDeadlineAt,
                settlementAvailableAt,
                metadataURI,
            )
            .then((tx) => tx.wait())
        const log = tx?.logs.find((log) =>
            BetchaRoundFactory__factory.createInterface().parseLog(log as any),
        ) as any
        const round = (await new BetchaRound__factory(deployer).attach(log.args[0])) as BetchaRound
        // Make bets
        await wagerToken.connect(bob).approve(await round.getAddress(), wagerTokenAmount)
        await expect(round.connect(bob).aightBet(0))
            .to.emit(round, 'Wagered')
            .withArgs(bob.address, await wagerToken.getAddress(), wagerTokenAmount)
        await wagerToken.connect(alice).approve(await round.getAddress(), wagerTokenAmount)
        await expect(round.connect(alice).aightBet(1))
            .to.emit(round, 'Wagered')
            .withArgs(alice.address, await wagerToken.getAddress(), wagerTokenAmount)
        expect(await round.totalParticipants()).to.eq(2)
        expect(await round.totalWageredAmount()).to.eq(wagerTokenAmount * 2)
        // Failure mode: can't bet after wager deadline
        await time.increaseTo(wagerDeadlineAt + 1)
        await wagerToken.connect(deployer).approve(await round.getAddress(), wagerTokenAmount)
        await expect(round.aightBet(0)).to.be.revertedWith('Wager deadline has passed')

        // Failure mode: can't settle before available date
        await expect(round.settle(0)).to.be.revertedWith('Wait longer')
        // Settle
        await time.increaseTo(settlementAvailableAt + 1)
        await expect(round.settle(0)).to.emit(round, 'Settled').withArgs(0)

        // Claim
        await expect(round.claim(deployer.address)).to.be.revertedWith(`Caller didn't wager`)
        await expect(round.claim(bob.address)).to.emit(round, 'Payout')
        await expect(round.claim(alice.address)).to.be.rejectedWith('Caller did not win')
    })
})
