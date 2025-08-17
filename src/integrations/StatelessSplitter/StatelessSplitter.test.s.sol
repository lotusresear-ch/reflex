// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./StatelessSplitter.sol";

contract TestableSplitter is StatelessSplitter {
    address private _admin;

    constructor(address admin_, address[] memory recipients_, uint256[] memory sharesBps_) StatelessSplitter() {
        _admin = admin_;
        _setShares(recipients_, sharesBps_);
    }

    function _onlyAdmin() internal view override {
        require(msg.sender == _admin, "NotAdmin");
    }
}

contract StatelessSplitterTest is Test {
    TestableSplitter public splitter;
    address public admin;
    address public alice = address(0xA);
    address public bob = address(0xB);
    address public charlie = address(0xC);
    address public diana = address(0xD);

    address[] public recipients;
    uint256[] public shares;

    receive() external payable {}

    function setUp() public {
        admin = address(this);

        recipients = new address[](4);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = charlie;
        recipients[3] = diana;

        shares = new uint256[](4);
        shares[0] = 2500; // 25%
        shares[1] = 2500; // 25%
        shares[2] = 2500; // 25%
        shares[3] = 2500; // 25%

        splitter = new TestableSplitter(admin, recipients, shares);
    }

    function testGetRecipients() public view {
        (address[] memory r, uint256[] memory s) = splitter.getRecipients();
        assertEq(r.length, 4);
        assertEq(s.length, 4);
        assertEq(r[0], alice);
        assertEq(r[1], bob);
        assertEq(r[2], charlie);
        assertEq(r[3], diana);
        assertEq(s[0], 2500);
        assertEq(s[1], 2500);
        assertEq(s[2], 2500);
        assertEq(s[3], 2500);
    }

    function testUpdateShares() public {
        address[] memory newRecipients = new address[](4);
        newRecipients[0] = alice;
        newRecipients[1] = bob;
        newRecipients[2] = charlie;
        newRecipients[3] = diana;

        uint256[] memory newShares = new uint256[](4);
        newShares[0] = 1000;
        newShares[1] = 2000;
        newShares[2] = 3000;
        newShares[3] = 4000;

        splitter.updateShares(newRecipients, newShares);

        (address[] memory r, uint256[] memory s) = splitter.getRecipients();
        assertEq(r.length, 4);
        assertEq(r[0], alice);
        assertEq(s[3], 4000);
    }

    function testUnauthorizedUpdateFails() public {
        address attacker = address(0xBAD);
        vm.prank(attacker);

        address[] memory newRecipients = new address[](1);
        newRecipients[0] = alice;

        uint256[] memory newShares = new uint256[](1);
        newShares[0] = 10000;

        vm.expectRevert("NotAdmin");
        splitter.updateShares(newRecipients, newShares);
    }

    function test_RevertWhen_EmptyRecipients() public {
        address[] memory newRecipients = new address[](0);
        uint256[] memory newShares = new uint256[](0);

        vm.expectRevert("Invalid total shares");
        splitter.updateShares(newRecipients, newShares);
    }

    function test_RevertWhen_ZeroShare() public {
        address[] memory newRecipients = new address[](2);
        newRecipients[0] = alice;
        newRecipients[1] = bob;

        uint256[] memory newShares = new uint256[](2);
        newShares[0] = 0;
        newShares[1] = 10000;

        vm.expectRevert("Invalid recipient or share");
        splitter.updateShares(newRecipients, newShares);
    }

    function test_RevertWhen_ZeroAddress() public {
        address[] memory newRecipients = new address[](2);
        newRecipients[0] = address(0);
        newRecipients[1] = bob;

        uint256[] memory newShares = new uint256[](2);
        newShares[0] = 5000;
        newShares[1] = 5000;

        vm.expectRevert("Invalid recipient or share");
        splitter.updateShares(newRecipients, newShares);
    }

    function test_RevertWhen_InvalidTotalShares() public {
        address[] memory newRecipients = new address[](2);
        newRecipients[0] = alice;
        newRecipients[1] = bob;

        uint256[] memory newShares = new uint256[](2);
        newShares[0] = 3000;
        newShares[1] = 3000; // Total: 6000, should be 10000

        vm.expectRevert("Invalid total shares");
        splitter.updateShares(newRecipients, newShares);
    }

    function test_RevertWhen_LengthMismatch() public {
        address[] memory newRecipients = new address[](2);
        newRecipients[0] = alice;
        newRecipients[1] = bob;

        uint256[] memory newShares = new uint256[](3);
        newShares[0] = 5000;
        newShares[1] = 5000;
        newShares[2] = 0;

        vm.expectRevert("Recipients and shares length mismatch");
        splitter.updateShares(newRecipients, newShares);
    }

    function test_UpdateSharesWithDifferentRecipients() public {
        address eve = address(0xE);
        address frank = address(0xF);

        address[] memory newRecipients = new address[](2);
        newRecipients[0] = eve;
        newRecipients[1] = frank;

        uint256[] memory newShares = new uint256[](2);
        newShares[0] = 6000; // 60%
        newShares[1] = 4000; // 40%

        splitter.updateShares(newRecipients, newShares);

        (address[] memory r, uint256[] memory s) = splitter.getRecipients();
        assertEq(r.length, 2);
        assertEq(r[0], eve);
        assertEq(r[1], frank);
        assertEq(s[0], 6000);
        assertEq(s[1], 4000);
    }

    function test_UpdateSharesWithSingleRecipient() public {
        address[] memory newRecipients = new address[](1);
        newRecipients[0] = alice;

        uint256[] memory newShares = new uint256[](1);
        newShares[0] = 10000; // 100%

        splitter.updateShares(newRecipients, newShares);

        (address[] memory r, uint256[] memory s) = splitter.getRecipients();
        assertEq(r.length, 1);
        assertEq(r[0], alice);
        assertEq(s[0], 10000);
    }

    function test_SharesUpdatedEvent() public {
        address[] memory newRecipients = new address[](2);
        newRecipients[0] = alice;
        newRecipients[1] = bob;

        uint256[] memory newShares = new uint256[](2);
        newShares[0] = 7000;
        newShares[1] = 3000;

        vm.expectEmit(true, true, true, true);
        emit SharesUpdated(newRecipients, newShares);

        splitter.updateShares(newRecipients, newShares);
    }

    event SharesUpdated(address[] recipients, uint256[] sharesBps);

    // ========== Fuzz Tests ==========

    function testFuzz_UpdateSharesValidTotal(uint256 share1, uint256 share2) public {
        // Bound shares to reasonable values that sum to TOTAL_BPS
        vm.assume(share1 > 0 && share1 < 10000);
        share2 = 10000 - share1;
        vm.assume(share2 > 0);

        address[] memory newRecipients = new address[](2);
        newRecipients[0] = alice;
        newRecipients[1] = bob;

        uint256[] memory newShares = new uint256[](2);
        newShares[0] = share1;
        newShares[1] = share2;

        splitter.updateShares(newRecipients, newShares);

        (address[] memory r, uint256[] memory s) = splitter.getRecipients();
        assertEq(r.length, 2);
        assertEq(s[0], share1);
        assertEq(s[1], share2);
        assertEq(s[0] + s[1], 10000);
    }

    function testFuzz_UpdateSharesInvalidTotal(uint256 share1, uint256 share2) public {
        // Test cases where total doesn't equal 10000
        // Bound inputs to reasonable ranges to prevent overflow
        share1 = bound(share1, 1, 15000);
        share2 = bound(share2, 1, 15000);

        // Ensure they don't sum to exactly 10000
        vm.assume(share1 + share2 != 10000);

        address[] memory newRecipients = new address[](2);
        newRecipients[0] = alice;
        newRecipients[1] = bob;

        uint256[] memory newShares = new uint256[](2);
        newShares[0] = share1;
        newShares[1] = share2;

        vm.expectRevert("Invalid total shares");
        splitter.updateShares(newRecipients, newShares);
    }

    function testFuzz_UpdateSharesThreeRecipients(uint256 share1, uint256 share2, uint256 share3) public {
        // Test with three recipients
        vm.assume(share1 > 0 && share2 > 0 && share3 > 0);
        vm.assume(share1 < 3333 && share2 < 3333 && share3 < 3333); // Smaller bounds to ensure sum can equal 10000

        // Calculate share3 to make total exactly 10000
        uint256 remainingShare = 10000 - share1 - share2;
        vm.assume(remainingShare > 0 && remainingShare <= 10000);
        share3 = remainingShare;

        address[] memory newRecipients = new address[](3);
        newRecipients[0] = alice;
        newRecipients[1] = bob;
        newRecipients[2] = charlie;

        uint256[] memory newShares = new uint256[](3);
        newShares[0] = share1;
        newShares[1] = share2;
        newShares[2] = share3;

        splitter.updateShares(newRecipients, newShares);

        (address[] memory r, uint256[] memory s) = splitter.getRecipients();
        assertEq(r.length, 3);
        assertEq(s[0] + s[1] + s[2], 10000);
    }

    function testFuzz_GetRecipientsConsistency(uint256 numRecipients) public {
        // Test with different numbers of recipients (1-10)
        numRecipients = bound(numRecipients, 1, 10);

        address[] memory newRecipients = new address[](numRecipients);
        uint256[] memory newShares = new uint256[](numRecipients);

        // Create recipients with equal shares
        uint256 sharePerRecipient = 10000 / numRecipients;
        uint256 remainder = 10000 % numRecipients;

        for (uint256 i = 0; i < numRecipients; i++) {
            newRecipients[i] = address(uint160(0x1000 + i)); // Generate unique addresses
            newShares[i] = sharePerRecipient;
            if (i == 0) {
                newShares[i] += remainder; // Give remainder to first recipient
            }
        }

        splitter.updateShares(newRecipients, newShares);

        (address[] memory r, uint256[] memory s) = splitter.getRecipients();
        assertEq(r.length, numRecipients);
        assertEq(s.length, numRecipients);

        // Verify total shares
        uint256 total = 0;
        for (uint256 i = 0; i < s.length; i++) {
            total += s[i];
        }
        assertEq(total, 10000);
    }

    function testFuzz_RevertOnZeroShare(uint256 validShare, uint256 invalidIndex) public {
        // Test that zero shares are rejected at any position
        vm.assume(validShare > 0 && validShare < 10000);

        uint256 numRecipients = 3;
        invalidIndex = bound(invalidIndex, 0, numRecipients - 1);

        address[] memory newRecipients = new address[](numRecipients);
        uint256[] memory newShares = new uint256[](numRecipients);

        for (uint256 i = 0; i < numRecipients; i++) {
            newRecipients[i] = address(uint160(0x2000 + i));
            if (i == invalidIndex) {
                newShares[i] = 0; // Set one share to zero
            } else {
                newShares[i] = validShare;
            }
        }

        vm.expectRevert("Invalid recipient or share");
        splitter.updateShares(newRecipients, newShares);
    }

    function testFuzz_EdgeCaseShares(uint256 seed) public {
        // Test extreme but valid share distributions
        seed = bound(seed, 0, 2);

        address[] memory newRecipients = new address[](2);
        newRecipients[0] = alice;
        newRecipients[1] = bob;

        uint256[] memory newShares = new uint256[](2);

        if (seed == 0) {
            // One recipient gets almost everything
            newShares[0] = 9999;
            newShares[1] = 1;
        } else if (seed == 1) {
            // Reverse distribution
            newShares[0] = 1;
            newShares[1] = 9999;
        } else {
            // Equal split
            newShares[0] = 5000;
            newShares[1] = 5000;
        }

        splitter.updateShares(newRecipients, newShares);

        (, uint256[] memory s) = splitter.getRecipients();
        assertEq(s[0] + s[1], 10000);
        assertTrue(s[0] > 0 && s[1] > 0);
    }

    // ========== Property-Based Tests ==========

    function testProperty_SharesSumToTotalBps() public {
        // Property: shares should always sum to TOTAL_BPS after valid update
        address[] memory newRecipients = new address[](3);
        newRecipients[0] = alice;
        newRecipients[1] = bob;
        newRecipients[2] = charlie;

        uint256[] memory newShares = new uint256[](3);
        newShares[0] = 3333;
        newShares[1] = 3333;
        newShares[2] = 3334; // 3333 + 3333 + 3334 = 10000

        splitter.updateShares(newRecipients, newShares);

        (, uint256[] memory s) = splitter.getRecipients();

        uint256 total = 0;
        for (uint256 i = 0; i < s.length; i++) {
            total += s[i];
        }

        assertEq(total, splitter.TOTAL_BPS());
        assertEq(total, 10000);
    }

    function testProperty_AllRecipientsHavePositiveShares() public view {
        // Property: all recipients should have positive shares
        (address[] memory r, uint256[] memory s) = splitter.getRecipients();

        for (uint256 i = 0; i < s.length; i++) {
            assertTrue(s[i] > 0, "All shares must be positive");
            assertTrue(r[i] != address(0), "All recipients must be valid addresses");
        }
    }

    function testProperty_RecipientsArrayLengthMatchesSharesArray() public view {
        // Property: recipients and shares arrays should always have same length
        (address[] memory r, uint256[] memory s) = splitter.getRecipients();
        assertEq(r.length, s.length);
    }

    // ========== Invariant Tests ==========

    function invariant_TotalSharesAlways10000() public view {
        (, uint256[] memory s) = splitter.getRecipients();

        uint256 total = 0;
        for (uint256 i = 0; i < s.length; i++) {
            total += s[i];
        }

        assertEq(total, 10000);
    }

    function invariant_NoZeroSharesOrAddresses() public view {
        (address[] memory r, uint256[] memory s) = splitter.getRecipients();

        for (uint256 i = 0; i < r.length; i++) {
            assertTrue(r[i] != address(0));
            assertTrue(s[i] > 0);
        }
    }
}
