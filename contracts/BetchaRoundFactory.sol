// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ISafe} from "./interfaces/ISafe.sol";
import {ISafeProxyFactory} from "./interfaces/ISafeProxyFactory.sol";
import {BetchaRound} from "./BetchaRound.sol";

/// @title BetchaRoundFactory
/// @author kevincharm
/// @notice Deploys betcha rounds
contract BetchaRoundFactory {
    /// @notice Gnosis Safe proxy factory
    address public safeProxyFactory;
    /// @notice Gnosis Safe implementation
    address public safeMasterCopy;
    /// @notice BetchaRound implementation
    address public betchaRoundMasterCopy;

    event BetchaRoundCreated(address indexed deployedAddress);

    constructor(
        address safeProxyFactory_,
        address safeMasterCopy_,
        address initialMasterCopy
    ) {
        safeProxyFactory = safeProxyFactory_;
        safeMasterCopy = safeMasterCopy_;
        betchaRoundMasterCopy = initialMasterCopy;
    }

    function createRound(
        address wagerTokenAddress,
        uint256 wagerTokenAmount,
        address[] calldata resolvers,
        uint256 wagerDeadlineAt,
        uint256 settlementAvailableAt
    ) public returns (address) {
        // Deploy a Safe as the multisig resolver if |resolvers| > 1
        address resolver = resolvers[0];
        if (resolvers.length > 1) {
            resolver = ISafeProxyFactory(safeProxyFactory).createProxyWithNonce(
                    safeMasterCopy,
                    "0x",
                    computeSafeProxySalt(nonce)
                );
            // TODO: Encode this above
            resolver.setup(
                resolvers,
                resolvers.length,
                address(0),
                "0x",
                address(0),
                address(0),
                0,
                payable(0)
            );
        }

        BetchaRound round = new BetchaRound(
            wagerTokenAddress,
            wagerTokenAmount,
            resolver,
            wagerDeadlineAt,
            settlementAvailableAt
        );
        emit BetchaRoundCreated(address(round));
        return address(round);
    }
}
