// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/// @title ISafeProxyFactory
/// @notice Gnosis Safe's proxy factory interface
interface ISafeProxyFactory {
    function proxyCreationCode() external pure returns (bytes memory);

    function createProxyWithNonce(
        address _singleton,
        bytes memory initializer,
        uint256 saltNonce
    ) external returns (address proxy);
}
