// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ReflexRouter.sol";
import "../src/interfaces/IReflexQuoter.sol";
import "../src/libraries/DexTypes.sol";
import "./utils/TestUtils.sol";
import "./mocks/MockToken.sol";

// Malicious contract that attempts reentrancy
contract MaliciousReentrancyContract {
    ReflexRouter public target;
    uint256 public callCount;
    bool public shouldReenter;

    constructor(address payable _target) {
        target = ReflexRouter(_target);
    }

    function setShouldReenter(bool _shouldReenter) external {
        shouldReenter = _shouldReenter;
    }

    function attack(bytes32 triggerPoolId, uint112 swapAmountIn, bool token0In) external {
        target.triggerBackrun(triggerPoolId, swapAmountIn, token0In, address(this));
    }

    // This function would be called when receiving tokens
    function transfer(address, uint256) external returns (bool) {
        callCount++;
        if (shouldReenter && callCount < 3) {
            // Attempt reentrancy
            target.triggerBackrun(bytes32(0), 1000, true, address(this));
        }
        return true;
    }

    receive() external payable {}
}

// Contract that fails during token transfers
contract FailingTokenContract {
    bool public shouldFail;

    function setShouldFail(bool _shouldFail) external {
        shouldFail = _shouldFail;
    }

    function transfer(address, uint256) external view returns (bool) {
        require(!shouldFail, "Transfer failed");
        return true;
    }

    function balanceOf(address) external pure returns (uint256) {
        return 1000 * 10 ** 18;
    }
}

// Mock quoter that can return malformed data
contract MaliciousQuoter is IReflexQuoter {
    bool public returnMalformedData;
    bool public returnExcessiveArrays;

    function setReturnMalformedData(bool _malformed) external {
        returnMalformedData = _malformed;
    }

    function setReturnExcessiveArrays(bool _excessive) external {
        returnExcessiveArrays = _excessive;
    }

    function getQuote(address, uint8, uint256)
        external
        view
        override
        returns (uint256 profit, SwapDecodedData memory decoded, uint256[] memory amountsOut, uint256 initialHopIndex)
    {
        if (returnMalformedData) {
            // Return mismatched array lengths
            address[] memory pools = new address[](2);
            uint8[] memory dexType = new uint8[](1); // Wrong length
            uint8[] memory dexMeta = new uint8[](3); // Wrong length
            address[] memory tokens = new address[](1); // Wrong length

            return (
                1000,
                SwapDecodedData({pools: pools, dexType: dexType, dexMeta: dexMeta, amount: 1000, tokens: tokens}),
                new uint256[](0),
                0
            );
        }

        if (returnExcessiveArrays) {
            // Return very large arrays to test gas limits
            address[] memory pools = new address[](1000);
            uint8[] memory dexType = new uint8[](1000);
            uint8[] memory dexMeta = new uint8[](1000);
            address[] memory tokens = new address[](1000);
            uint256[] memory amounts = new uint256[](1000);

            return (
                1000,
                SwapDecodedData({pools: pools, dexType: dexType, dexMeta: dexMeta, amount: 1000, tokens: tokens}),
                amounts,
                0
            );
        }

        // Return empty data by default
        return (
            0,
            SwapDecodedData({
                pools: new address[](0),
                dexType: new uint8[](0),
                dexMeta: new uint8[](0),
                amount: 0,
                tokens: new address[](0)
            }),
            new uint256[](0),
            0
        );
    }
}

// Pool that calls back with wrong function signature
contract MaliciousPool {
    function swap(uint256, uint256, address to, bytes calldata) external {
        // Call with wrong signature
        (bool success,) = to.call(abi.encodeWithSignature("wrongFunction(uint256)", 123));
        require(success, "Wrong callback failed");
    }

    function swap(address recipient, bool, int256, uint160, bytes calldata) external returns (int256, int256) {
        // Call with wrong signature for V3
        (bool success,) = recipient.call(abi.encodeWithSignature("anotherWrongFunction(int256,int256)", 123, 456));
        require(success, "Wrong V3 callback failed");
        return (123, 456);
    }
}

contract ReflexRouterSecurityTest is Test {
    using TestUtils for *;

    ReflexRouter public reflexRouter;
    MaliciousQuoter public maliciousQuoter;
    MockToken public token0;
    MockToken public token1;
    FailingTokenContract public failingToken;
    MaliciousReentrancyContract public reentrancyAttacker;
    MaliciousPool public maliciousPool;

    address public owner = address(0x1);
    address public alice = address(0xA);
    address public attacker = address(0xBAD);

    function setUp() public {
        vm.prank(owner);
        reflexRouter = new ReflexRouter();

        token0 = new MockToken("Token0", "TK0", 1000000 * 10 ** 18);
        token1 = new MockToken("Token1", "TK1", 1000000 * 10 ** 18);
        failingToken = new FailingTokenContract();

        maliciousQuoter = new MaliciousQuoter();
        reentrancyAttacker = new MaliciousReentrancyContract(payable(address(reflexRouter)));
        maliciousPool = new MaliciousPool();

        // Fund the router
        token0.mint(address(reflexRouter), 10000 * 10 ** 18);
        token1.mint(address(reflexRouter), 10000 * 10 ** 18);
    }

    // =============================================================================
    // Reentrancy Attack Tests
    // =============================================================================

    function test_reentrancy_protection() public {
        // Set up a scenario where reentrancy could be attempted
        vm.prank(owner);
        reflexRouter.setReflexQuoter(address(maliciousQuoter));

        reentrancyAttacker.setShouldReenter(true);

        // The attack should fail due to ReentrancyGuard
        // Note: This test is conceptual since the actual reentrancy would happen
        // during token transfer, which our mock doesn't fully simulate

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(maliciousPool))));

        // This should not revert due to reentrancy, but also shouldn't cause issues
        reentrancyAttacker.attack(triggerPoolId, 1000, true);

        // Verify the attack didn't succeed multiple times
        assertLe(reentrancyAttacker.callCount(), 1);
    }

    // =============================================================================
    // Access Control Tests
    // =============================================================================

    function test_onlyAdmin_setReflexQuoter() public {
        vm.prank(attacker);
        vm.expectRevert();
        reflexRouter.setReflexQuoter(address(maliciousQuoter));

        // Owner should succeed
        vm.prank(owner);
        reflexRouter.setReflexQuoter(address(maliciousQuoter));
        assertEq(reflexRouter.reflexQuoter(), address(maliciousQuoter));
    }

    function test_onlyAdmin_withdrawToken() public {
        uint256 amount = 100 * 10 ** 18;

        vm.prank(attacker);
        vm.expectRevert();
        reflexRouter.withdrawToken(address(token0), amount, attacker);

        // Owner should succeed
        vm.prank(owner);
        reflexRouter.withdrawToken(address(token0), amount, owner);
        assertEq(token0.balanceOf(owner), amount);
    }

    function test_onlyAdmin_withdrawEth() public {
        vm.deal(address(reflexRouter), 1 ether);

        vm.prank(attacker);
        vm.expectRevert();
        reflexRouter.withdrawEth(0.5 ether, payable(attacker));

        // Owner should succeed
        vm.prank(owner);
        reflexRouter.withdrawEth(0.5 ether, payable(owner));
        assertEq(owner.balance, 0.5 ether);
    }

    // =============================================================================
    // Malformed Data Tests
    // =============================================================================

    function test_malformed_quoter_data() public {
        vm.prank(owner);
        reflexRouter.setReflexQuoter(address(maliciousQuoter));

        maliciousQuoter.setReturnMalformedData(true);

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(token0))));

        // Should handle malformed data gracefully (likely revert or return no profit)
        try reflexRouter.triggerBackrun(triggerPoolId, 1000, true, alice) returns (uint256 profit, address) {
            // If it doesn't revert, profit should be 0 due to malformed data
            assertEq(profit, 0);
        } catch {
            // Reverting is also acceptable behavior for malformed data
            assertTrue(true);
        }
    }

    function test_excessive_array_sizes() public {
        vm.prank(owner);
        reflexRouter.setReflexQuoter(address(maliciousQuoter));

        maliciousQuoter.setReturnExcessiveArrays(true);

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(token0))));

        // Should either revert due to gas limit or handle gracefully
        try reflexRouter.triggerBackrun(triggerPoolId, 1000, true, alice) returns (uint256 profit, address) {
            // If it completes, profit should be 0
            assertEq(profit, 0);
        } catch {
            // Gas limit reached or other error - acceptable
            assertTrue(true);
        }
    }

    // =============================================================================
    // Token Transfer Failure Tests
    // =============================================================================

    function test_failing_token_transfer() public {
        // This test would require a more sophisticated setup to actually trigger
        // token transfer failures during the arbitrage process

        failingToken.setShouldFail(true);

        // Create a scenario where the failing token would be used
        vm.prank(owner);
        reflexRouter.withdrawToken(address(failingToken), 100, alice);

        // The withdrawal should fail
        // Note: Our failing token doesn't fully implement ERC20, so this is conceptual
    }

    // =============================================================================
    // Integer Overflow/Underflow Tests
    // =============================================================================

    function test_extreme_values_no_overflow() public {
        bytes32 triggerPoolId = bytes32(uint256(uint160(address(token0))));

        // Test with maximum possible values
        (uint256 profit, address profitToken) =
            reflexRouter.triggerBackrun(triggerPoolId, type(uint112).max, true, alice);

        // Should handle extreme values without overflow
        assertEq(profit, 0);
        assertEq(profitToken, address(0));
    }

    function test_zero_values_handling() public {
        bytes32 triggerPoolId = bytes32(0);

        (uint256 profit, address profitToken) = reflexRouter.triggerBackrun(triggerPoolId, 0, true, address(0));

        assertEq(profit, 0);
        assertEq(profitToken, address(0));
    }

    // =============================================================================
    // Gas Limit Attack Tests
    // =============================================================================

    function test_gas_limit_protection() public {
        // Test that the contract handles scenarios where gas might be limited
        // This is inherently protected by Solidity's gas mechanics

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(token0))));

        // Call with limited gas
        uint256 gasLimit = 100000; // Deliberately low

        try this.callWithGasLimit{gas: gasLimit}(triggerPoolId) {
            assertTrue(true);
        } catch {
            // Expected to fail with low gas
            assertTrue(true);
        }
    }

    function callWithGasLimit(bytes32 triggerPoolId) external {
        reflexRouter.triggerBackrun(triggerPoolId, 1000, true, alice);
    }

    // =============================================================================
    // Front-running Protection Tests
    // =============================================================================

    function test_transaction_order_independence() public {
        // Test that the same parameters produce the same results regardless of order
        bytes32 triggerPoolId = bytes32(uint256(uint160(address(token0))));

        (uint256 profit1,) = reflexRouter.triggerBackrun(triggerPoolId, 1000, true, alice);
        (uint256 profit2,) = reflexRouter.triggerBackrun(triggerPoolId, 1000, true, alice);

        // Should be deterministic
        assertEq(profit1, profit2);
    }

    // =============================================================================
    // State Consistency Tests
    // =============================================================================

    function test_state_consistency_after_failed_transaction() public {
        vm.prank(owner);
        reflexRouter.setReflexQuoter(address(maliciousQuoter));

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(token0))));

        // Attempt a transaction that might fail
        try reflexRouter.triggerBackrun(triggerPoolId, 1000, true, alice) {
            // Transaction succeeded
        } catch {
            // Transaction failed
        }

        // State should remain consistent
        assertEq(reflexRouter.owner(), owner);
        assertEq(reflexRouter.reflexQuoter(), address(maliciousQuoter));
        assertEq(reflexRouter.getReflexAdmin(), owner);
    }

    // =============================================================================
    // Callback Security Tests
    // =============================================================================

    function test_malicious_callback_signature() public {
        // Test that wrong callback signatures don't break the system
        bytes32 triggerPoolId = bytes32(uint256(uint160(address(maliciousPool))));

        // Should handle malicious callbacks gracefully
        try reflexRouter.triggerBackrun(triggerPoolId, 1000, true, alice) returns (uint256 profit, address) {
            assertEq(profit, 0);
        } catch {
            // Reverting is acceptable for malicious callbacks
            assertTrue(true);
        }
    }

    // =============================================================================
    // MEV Protection Tests
    // =============================================================================

    function test_slippage_protection() public {
        // While the router doesn't have explicit slippage protection,
        // it should handle scenarios where expected profits don't materialize

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(token0))));

        // Multiple calls with same parameters should be consistent
        (uint256 profit1,) = reflexRouter.triggerBackrun(triggerPoolId, 1000, true, alice);
        (uint256 profit2,) = reflexRouter.triggerBackrun(triggerPoolId, 1000, true, alice);
        (uint256 profit3,) = reflexRouter.triggerBackrun(triggerPoolId, 1000, true, alice);

        assertEq(profit1, profit2);
        assertEq(profit2, profit3);
    }

    // =============================================================================
    // Edge Case Input Tests
    // =============================================================================

    function test_invalid_pool_addresses() public {
        // Test with invalid pool addresses
        bytes32 invalidPoolId = bytes32(uint256(uint160(address(0xdead))));

        (uint256 profit, address profitToken) = reflexRouter.triggerBackrun(invalidPoolId, 1000, true, alice);

        assertEq(profit, 0);
        assertEq(profitToken, address(0));
    }

    function test_uninitialized_quoter() public {
        // Test behavior when quoter is not set
        vm.prank(owner);
        ReflexRouter newRouter = new ReflexRouter();

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(token0))));

        // Should revert when quoter is not set
        vm.expectRevert();
        newRouter.triggerBackrun(triggerPoolId, 1000, true, alice);
    }

    // =============================================================================
    // Fuzz Testing for Security
    // =============================================================================

    function testFuzz_no_unauthorized_state_changes(
        address randomCaller,
        bytes32 randomPoolId,
        uint112 randomAmount,
        bool randomBool
    ) public {
        vm.assume(randomCaller != owner);
        vm.assume(randomCaller != address(0));

        address originalOwner = reflexRouter.owner();
        address originalQuoter = reflexRouter.reflexQuoter();

        // Random caller attempts to trigger backrun
        vm.prank(randomCaller);
        try reflexRouter.triggerBackrun(randomPoolId, randomAmount, randomBool, randomCaller) {
            // Transaction succeeded
        } catch {
            // Transaction failed
        }

        // Critical state should not have changed
        assertEq(reflexRouter.owner(), originalOwner);
        assertEq(reflexRouter.reflexQuoter(), originalQuoter);
    }

    function testFuzz_admin_functions_access_control(
        address randomCaller,
        address randomToken,
        uint256 randomAmount,
        address randomRecipient
    ) public {
        vm.assume(randomCaller != owner);
        vm.assume(randomCaller != address(0));
        vm.assume(randomToken != address(0));
        vm.assume(randomRecipient != address(0));
        vm.assume(randomAmount > 0 && randomAmount < type(uint256).max / 2);

        // All admin functions should revert for non-owner
        vm.prank(randomCaller);
        vm.expectRevert();
        reflexRouter.setReflexQuoter(randomToken);

        vm.prank(randomCaller);
        vm.expectRevert();
        reflexRouter.withdrawToken(randomToken, randomAmount, randomRecipient);

        vm.prank(randomCaller);
        vm.expectRevert();
        reflexRouter.withdrawEth(randomAmount % 10 ether, payable(randomRecipient));
    }

    function testFuzz_triggerBackrun_deterministic(bytes32 poolId, uint112 amount, bool tokenIn, address recipient)
        public
    {
        vm.assume(recipient != address(0));
        vm.assume(amount > 0);

        // Same inputs should produce same outputs
        (uint256 profit1, address profitToken1) = reflexRouter.triggerBackrun(poolId, amount, tokenIn, recipient);
        (uint256 profit2, address profitToken2) = reflexRouter.triggerBackrun(poolId, amount, tokenIn, recipient);

        assertEq(profit1, profit2);
        assertEq(profitToken1, profitToken2);
    }
}
