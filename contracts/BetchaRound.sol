// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Sets} from "./lib/Sets.sol";

/// @title BetchaRound
/// @author kevincharm
/// @notice Round contract & escrow for wager pool
contract BetchaRound is Initializable {
    using SafeERC20 for ERC20;
    using Sets for Sets.Set;

    struct SettlementInformation {
        bool hasSettled;
        uint8 outcome;
    }

    /// @notice Wager token address. 0 for Ether/native currency
    address public wagerTokenAddress;
    /// @notice Wager token amount, in the token's respective decimal
    ///     resolution (or wei in case of Ether)
    uint256 public wagerTokenAmount;
    /// @notice Deadline to put in bets
    uint256 public wagerDeadlineAt;
    /// @notice Earliest time that the contract can be settled
    uint256 public settlementAvailableAt;
    /// @notice The EOA or contract that will settle the final outcome of
    address public resolver;

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
    event MessagePosted(address indexed author, string content);

    constructor() {
        _disableInitializers();
    }

    function init(
        address wagerTokenAddress_,
        uint256 wagerTokenAmount_,
        address resolver_,
        uint256 wagerDeadlineAt_,
        uint256 settlementAvailableAt_,
        string memory metadataURI_
    ) public initializer {
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

    /// @notice Assert that `outcome` is considered valid (0 or 1)
    /// @param outcome Outcome
    function _assertValidOutcome(uint8 outcome) internal pure {
        require(outcome <= 1, "Outcome must be binary");
    }

    /// @notice Place a wager
    /// @param outcome Caller's prediction
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

    /// @notice Settle the outcome of this bet
    /// @param outcome The final outcome of the bet
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

    /// @notice Get total number of addresses that placed a wager
    function totalParticipants() public view returns (uint256) {
        return outcome0Wagers.size + outcome1Wagers.size;
    }

    /// @notice Helper to determine if an address did place a wager
    /// @param whom Address to check
    /// @return true if `whom` did place a wager
    function isParticipating(address whom) public view returns (bool) {
        return outcome0Wagers.has(whom) || outcome1Wagers.has(whom);
    }

    /// @notice Claim winnings, if `recipient` is eligible
    /// @param recipient Alleged winner
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

    /// @notice Payout a share of the pot, if `to` has not already claimed
    /// @param to Where to payout
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

    /// @notice Post a message to the onchain conversation
    /// @param content Content of the message
    function post(string calldata content) external {
        require(isParticipating(msg.sender), "Only gamblers may post");
        emit MessagePosted(msg.sender, content);
    }
}
