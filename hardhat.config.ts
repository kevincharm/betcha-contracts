import type { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-verify'
import '@nomicfoundation/hardhat-toolbox'
import 'hardhat-contract-sizer'
import 'hardhat-abi-exporter'
import 'hardhat-gas-reporter'

const config: HardhatUserConfig = {
    solidity: {
        version: '0.8.19',
        settings: {
            viaIR: false,
            optimizer: {
                enabled: true,
                runs: 1000,
            },
        },
    },
    networks: {
        hardhat: {
            chainId: 137,
            forking: {
                enabled: true,
                url: process.env.BASE_URL as string,
                blockNumber: 4356900,
            },
            blockGasLimit: 155_000_000,
            accounts: {
                count: 10,
            },
        },
        base: {
            url: process.env.BASE_URL as string,
            chainId: 8453,
            accounts: [process.env.MAINNET_PK as string],
        },
    },
    gasReporter: {
        enabled: true,
        currency: 'USD',
        gasPrice: 60,
    },
    etherscan: {
        apiKey: {
            mainnet: process.env.ETHERSCAN_API_KEY as string,
            polygonMumbai: process.env.POLYGONSCAN_API_KEY as string,
            polygon: process.env.POLYGONSCAN_API_KEY as string,
            base: process.env.BASESCAN_API_KEY as string,
        },
    },
    contractSizer: {
        alphaSort: true,
        disambiguatePaths: false,
        runOnCompile: false,
        strict: true,
    },
    abiExporter: {
        path: './exported/abi',
        runOnCompile: true,
        clear: true,
        flat: true,
        only: ['Betcha'],
        except: ['test/*'],
    },
}

export default config
