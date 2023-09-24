// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
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
    /// @notice Betcha round implementation
    address public betchaRoundMasterCopy;
    /// @notice Nonce for deploying Safe proxies
    uint256 public nonce;

    event BetchaRoundCreated(address indexed deployedAddress);

    constructor(
        address safeProxyFactory_,
        address safeMasterCopy_,
        address betchaRoundMasterCopy_
    ) {
        safeProxyFactory = safeProxyFactory_;
        safeMasterCopy = safeMasterCopy_;
        betchaRoundMasterCopy = betchaRoundMasterCopy_;
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
                    abi.encodePacked(
                        ISafe.setup.selector,
                        abi.encode(
                            resolvers,
                            resolvers.length,
                            address(0),
                            bytes(""),
                            address(0),
                            address(0),
                            uint256(0),
                            payable(0)
                        )
                    ),
                    uint256(keccak256(abi.encode(address(this), nonce)))
                );
        }

        // Deploy round
        ERC1967Proxy roundProxy = new ERC1967Proxy(
            betchaRoundMasterCopy,
            abi.encodePacked(
                BetchaRound.init.selector,
                abi.encode(
                    wagerTokenAddress,
                    wagerTokenAmount,
                    resolver,
                    wagerDeadlineAt,
                    settlementAvailableAt,
                    metadataURI
                )
            )
        );
        emit BetchaRoundCreated(address(roundProxy));
        return address(roundProxy);
    }
}
