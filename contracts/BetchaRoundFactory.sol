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
    /// @notice Nonce for deploying Safe proxies
    uint256 public nonce;

    event BetchaRoundCreated(address indexed deployedAddress);

    constructor(address safeProxyFactory_, address safeMasterCopy_) {
        safeProxyFactory = safeProxyFactory_;
        safeMasterCopy = safeMasterCopy_;
    }

    function createRound(
        address wagerTokenAddress,
        uint256 wagerTokenAmount,
        address[] calldata resolvers,
        uint256 wagerDeadlineAt,
        uint256 settlementAvailableAt,
        string memory metadataURI
    ) public returns (address) {
        // Deploy a Safe as the multisig resolver if |resolvers| > 1
        address resolver = resolvers[0];
        if (resolvers.length > 1) {
            resolver = ISafeProxyFactory(safeProxyFactory).createProxyWithNonce(
                    safeMasterCopy,
                    "0x",
                    uint256(keccak256(abi.encode(address(this), nonce)))
                );
            // TODO: Encode this above
            ISafe(resolver).setup(
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
            settlementAvailableAt,
            metadataURI
        );
        emit BetchaRoundCreated(address(round));
        return address(round);
    }
}
