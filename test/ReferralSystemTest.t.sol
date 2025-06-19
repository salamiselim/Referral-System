// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import {ReferralSystem} from "../src/ReferralSystem.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
   
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract ReferralSystemTest is Test {
    ReferralSystem referralSystem;
    MockERC20 mockToken;

    address owner = makeAddr("owner");
    address referrer = makeAddr("referrer");
    address referee = makeAddr("referee");
    bytes32 referralId = ("test1");

    function setUp() public {
        vm.prank(owner);
        referralSystem = new ReferralSystem(500); // 5% fee
        mockToken = new MockERC20();

        vm.deal(owner, 1 ether); 
        vm.deal(referrer, 1 ether);
    }

    function testRecordReferral() public {
        vm.prank(owner);
        referralSystem.recordReferral(referralId, referrer, referee, 1 ether, address(0));

        (address referral, ,uint256 amount, ,) = referralSystem.referrals(referralId);
        assertEq(referral, referrer);
        assertEq(amount, 0.05 ether); // 5% of 1 ether
    }

    function testClaimEthCommission() public {
        vm.deal(address(referralSystem), 1 ether);
        vm.deal(referrer, 0);
        uint256 initialBalance = referrer.balance;

        vm.prank(owner);
        referralSystem.recordReferral(referralId, referrer, referee, 1 ether, address(0));

        vm.prank(referrer);
        referralSystem.claimCommission(referralId);

        assertEq(referrer.balance, initialBalance + 0.05 ether); // 5% of 1 ether in ETH
        (, , , ,bool paid) = referralSystem.referrals(referralId);
        assertTrue(paid); // Commission should be marked as paid
      
    }

    function testClaimERC20Commission() public {
        mockToken.mint(address(referralSystem), 1 ether);
        vm.prank(owner);
        referralSystem.recordReferral(referralId, referrer, referee, 1 ether, address(mockToken));

        vm.prank(referrer);
        referralSystem.claimCommission(referralId);

        assertEq(mockToken.balanceOf(referrer), 0.05 ether); // 5% of 1 ether in ERC20
        (, , , , bool paid) = referralSystem.referrals(referralId);
        assertTrue(paid); // Commission should be marked as paid
    }

    function testOnlyReferrerCanClaim() public {
        vm.prank(owner);
        referralSystem.recordReferral(referralId, referrer, referee, 1 ether, address(0));

        vm.expectRevert(ReferralSystem.Unauthorized.selector);
        referralSystem.claimCommission(referralId); // Non-referrer tries to claim
    }

    function testOnlyOwnerCanRecord() public {
        vm.expectRevert(ReferralSystem.Unauthorized.selector);
        referralSystem.recordReferral(referralId, referrer, referee, 1 ether, address(0)); // Non-owner tries to record
    }

    function testWithdrawFunds() public {
        vm.deal(address(referralSystem), 1 ether);
        mockToken.mint(address(referralSystem), 1000);

        vm.deal(owner, 0);
        uint256 initialOwnerBalance = owner.balance;
        uint256 initialTokenBalance = mockToken.balanceOf(owner);

        vm.prank(owner);
        referralSystem.withdrawFunds(address(0));
        
        vm.prank(owner);
        referralSystem.withdrawFunds(address(mockToken));

        assertEq(owner.balance, initialOwnerBalance + 1 ether); // Owner should receive 1 ether
        assertEq(mockToken.balanceOf(owner), initialTokenBalance + 1000); // Owner should receive 1000 tokens
}
    function testCannotDoubleClaimEthCommission() public {
        vm.deal(address(referralSystem), 1 ether);
        vm.deal(referrer, 0);
        uint256 initialBalance = referrer.balance;

        // Record the referral
        vm.prank(owner);
        referralSystem.recordReferral(referralId, referrer, referee, 1 ether, address(0));

       // Claim the commission for the first time
        vm.prank(referrer);
        referralSystem.claimCommission(referralId);

        assertEq(referrer.balance, initialBalance + 0.05 ether); // 5% of 1 ether in ETH
        (, , , , bool paid) = referralSystem.referrals(referralId);
        assertTrue(paid); // Commission should be marked as paid

        // Second claim should fail
        vm.prank(referrer);
        vm.expectRevert(ReferralSystem.CommissionAlreadyPaid.selector);
        referralSystem.claimCommission(referralId); // Attempt to claim again

        // Check that the balance remains unchanged
        assertEq(referrer.balance, initialBalance + 0.05 ether); // Balance should
    }

    function testCannotDoubleClaimERC20() public {
        mockToken.mint(address(referralSystem), 1000);
        vm.prank(owner);
        referralSystem.recordReferral(referralId, referrer, referee, 1000, address(mockToken));

        // Claim the commission for the first time
        vm.prank(referrer);
        referralSystem.claimCommission(referralId);
        assertEq(mockToken.balanceOf(referrer), 50); // 5% of 1000 in ERC20
        
        vm.prank(referrer);
        vm.expectRevert(ReferralSystem.CommissionAlreadyPaid.selector);
        referralSystem.claimCommission(referralId); // Attempt to claim again

        // Check that the balance remains unchanged
        assertEq(mockToken.balanceOf(referrer), 50); // Balance should still be 50
    }
 }