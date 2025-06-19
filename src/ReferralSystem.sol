// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title Referral System
 * @dev This is REFERRAL SYSTEM CONTRACT
 */

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ReferralSystem {
    using SafeERC20 for IERC20;

    address public immutable owner;
    uint256 public immutable referralFeeBasisPoints;
    uint256 public constant FEE_DENOMINATOR = 10_000;

    // Data Structure
    struct Referral{
        address referrer;
        address referee;
        uint256 commission;
        address paymentToken;
        bool paid;
    }

    // state variables
    mapping (bytes32 => Referral) public referrals;
    mapping (address => uint256) public referrerEarnings;

    // Events
    event ReferralRecorded(
        bytes32 indexed referralId,
        address indexed referrer,
        address indexed referee,
        uint256 amount,
        address paymentToken,
        uint256 commission
    );

    event CommissionPaid(
        bytes32 indexed referralId,
        address indexed referrer,
        uint256 commission,
        address paymentToken
    );

    event FeeUpdated(uint256 newBasisPoints);

    // Errors
    error Unauthorized();
    error InvalidConfiguration();
    error ReferralAlreadyExist();
    error CommissionAlreadyPaid();
    error InvalidPaymentToken();

    modifier onlyowner () {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor(uint256 _referralFeeBasicPoints) {
        if(_referralFeeBasicPoints > FEE_DENOMINATOR) revert InvalidConfiguration();
        owner = msg.sender;
        referralFeeBasisPoints = _referralFeeBasicPoints;
    }

    // FUNCTION FOR REFERRAL RECORD
    function recordReferral(
        bytes32 referralId,
        address referrer,
        address referee,
        uint256 amount,
        address paymentToken
    ) external onlyowner {
        if (referrals[referralId]. referrer != address(0)) {
            revert ReferralAlreadyExist();
        }

        uint256 commission = (amount * referralFeeBasisPoints) / FEE_DENOMINATOR;

        referrals[referralId] = Referral ({
            referrer: referrer,
            referee: referee,
            commission: commission,
            paymentToken: paymentToken,
            paid: false
        });

        referrerEarnings[referrer] += commission;

        emit ReferralRecorded(
            referralId,
            referrer,
            referee,
            amount,
            paymentToken,
            commission
        );
    }
     
     // FUNCTION TO CLAIM COMMISION
    function claimCommission(bytes32 referralId) external {
        Referral storage referral = referrals[referralId];

        if (referral.paid) revert CommissionAlreadyPaid();
        if (msg.sender != referral.referrer) revert Unauthorized();

        referral.paid = true;
        referrerEarnings[referral.referrer] -= referral.commission;

        if (referral.paymentToken == address(0)) {
            (bool success,) = msg.sender.call{value: referral.commission}("");
            if (!success) revert InvalidPaymentToken();
        } else {
            IERC20(referral.paymentToken). safeTransfer(
                msg.sender,
                referral.commission
            );
        }

        emit CommissionPaid(
            referralId,
            referral.referrer,
            referral.commission,
            referral.paymentToken
        );
    }

    // FUNCTION TO WITHDRAW FUNDS
    function withdrawFunds(address token) external onlyowner {
        if (token == address(0)) {
            (bool success,) = msg.sender.call{value: address(this).balance}("");
            if(!success) revert InvalidPaymentToken();
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransfer(msg.sender, balance);
        }
    }

    receive() external payable {}
}
