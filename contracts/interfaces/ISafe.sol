// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/// @title ISafe
/// @notice Simplified Gnosis Safe interface
interface ISafe {
    enum Operation {
        Call,
        DelegateCall
    }

    event SafeSetup(
        address indexed initiator,
        address[] owners,
        uint256 threshold,
        address initializer,
        address fallbackHandler
    );

    function enableModule(address module) external;

    function isModuleEnabled(address module) external view returns (bool);

    function setup(
        address[] calldata _owners,
        uint256 _threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
    ) external;
}
