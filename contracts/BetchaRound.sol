// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Sets} from "./lib/Sets.sol";

/// @title BetchaRound
/// @author kevincharm
/// @notice Round contract & escrow for wager pool
contract BetchaRound {
    using SafeERC20 for ERC20;
    using Sets for Sets.Set;

    struct SettlementInformation {
        bool hasSettled;
        uint8 outcome;
    }

    /// @notice Wager token address. 0 for Ether/native currency
    address public immutable wagerTokenAddress;
    /// @notice Wager token amount, in the token's respective decimal
    ///     resolution (or wei in case of Ether)
    uint256 public immutable wagerTokenAmount;
    /// @notice Deadline to put in bets
    uint256 public immutable wagerDeadlineAt;
    /// @notice Earliest time that the contract can be settled
    uint256 public immutable settlementAvailableAt;
    /// @notice The EOA or contract that will settle the final outcome of
    address public immutable resolver;

    /// @notice URI to metadata containing bet details
    string public metadataURI;
    /// @notice Running pot total
    uint256 public totalWageredAmount;
    /// @notice Users that wagered on outcome 0
    Sets.Set public outcome0Wagers;
    /// @notice Users that wagered on outcome 1
    Sets.Set public outcome1Wagers;
    /// @notice Settlement information
    SettlementInformation public settlementInfo;
    /// @notice Nullifier for claims
    mapping(address => bool) public hasClaimed;

    address constant NATIVE_ETH_TOKEN = address(0);

    event Payout(
        address indexed to,
        address indexed tokenAddress,
        uint256 amount
    );
    event Wagered(
        address indexed gambler,
        address indexed tokenAddress,
        uint256 amount
    );
    event Settled(uint8 outcome);

    constructor(
        address wagerTokenAddress_,
        uint256 wagerTokenAmount_,
        address resolver_,
        uint256 wagerDeadlineAt_,
        uint256 settlementAvailableAt_,
        string memory metadataURI_
    ) {
        wagerTokenAddress = wagerTokenAddress_;
        wagerTokenAmount = wagerTokenAmount_;
        require(
            settlementAvailableAt_ >= wagerDeadlineAt_,
            "Settlement must be on or after wager deadline"
        );
        wagerDeadlineAt = wagerDeadlineAt_;
        settlementAvailableAt = settlementAvailableAt_;
        resolver = resolver_;
        metadataURI = metadataURI_;

        // Initialise sets
        outcome0Wagers.init();
        outcome1Wagers.init();
    }

    function _assertValidOutcome(uint8 outcome) internal pure {
        require(outcome <= 1, "Outcome must be binary");
    }

    function aightBet(uint8 outcome) public payable {
        _assertValidOutcome(outcome);
        // Global conditions
        require(block.timestamp < wagerDeadlineAt, "Wager deadline has passed");
        require(
            !outcome0Wagers.has(msg.sender) && !outcome1Wagers.has(msg.sender),
            "Caller has already wagered"
        );

        if (outcome == 0) {
            outcome0Wagers.add(msg.sender);
        } else {
            outcome1Wagers.add(msg.sender);
        }
        require(
            outcome0Wagers.has(msg.sender) || outcome1Wagers.has(msg.sender),
            "Something went wrong"
        );

        if (wagerTokenAddress == NATIVE_ETH_TOKEN) {
            totalWageredAmount += msg.value;
            // Native ETH: payment is included in call
            require(msg.value >= wagerTokenAmount, "Insufficient wager amount");
        } else {
            totalWageredAmount += wagerTokenAmount;
            // ERC-20: Pull wager amount from caller
            ERC20(wagerTokenAddress).safeTransferFrom(
                msg.sender,
                address(this),
                wagerTokenAmount
            );
        }
        emit Wagered(msg.sender, wagerTokenAddress, wagerTokenAmount);
    }

    function settle(uint8 outcome) public {
        _assertValidOutcome(outcome);
        require(msg.sender == resolver, "Caller not authorised resolver");
        require(block.timestamp >= settlementAvailableAt, "Wait longer");

        SettlementInformation memory s = settlementInfo;
        require(!s.hasSettled, "Already settled");
        s.hasSettled = true;
        s.outcome = outcome;
        settlementInfo = s;

        emit Settled(outcome);
    }

    function totalParticipants() public view returns (uint256) {
        return outcome0Wagers.size + outcome1Wagers.size;
    }

    function claim(address recipient) public {
        SettlementInformation memory s = settlementInfo;
        require(s.hasSettled, "Not yet settled");

        bool didBetOutcome0 = outcome0Wagers.has(recipient);
        bool didBetOutcome1 = outcome1Wagers.has(recipient);
        require(didBetOutcome0 || didBetOutcome1, "Caller didn't wager");

        // Winning conditions
        if (
            (s.outcome == 0 && didBetOutcome0) ||
            (s.outcome == 1 && didBetOutcome1)
        ) {
            _payoutShare(recipient);
        } else {
            revert("Caller did not win");
        }
    }

    function _payoutShare(address to) internal {
        // Ensure caller didn't already claim
        require(!hasClaimed[to], "Already claimed");
        hasClaimed[to] = true;

        // Distribute share
        uint256 payoutAmount = totalWageredAmount / totalParticipants();
        if (wagerTokenAddress == NATIVE_ETH_TOKEN) {
            (bool success, ) = to.call{value: payoutAmount}("");
            require(success, "Could not payout ETH");
        } else {
            ERC20 token = ERC20(wagerTokenAddress);
            token.safeTransfer(to, payoutAmount);
        }
        emit Payout(to, wagerTokenAddress, payoutAmount);
    }
}
