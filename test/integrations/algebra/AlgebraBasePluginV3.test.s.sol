// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test} from "forge-std/Test.sol";
import {AlgebraBasePluginV3} from "@reflex/integrations/algebra/full/AlgebraBasePluginV3.sol";
import {IReflexRouter} from "@reflex/interfaces/IReflexRouter.sol";
import {TestUtils, MockToken} from "../../utils/TestUtils.sol";
import {IAlgebraPlugin} from "@cryptoalgebra/core/interfaces/plugin/IAlgebraPlugin.sol";

contract MockAlgebraPool {
    address public plugin;
    address public token0;
    address public token1;
    uint160 public sqrtPriceX96;
    int24 public tick;
    uint16 public fee;
    uint8 public pluginConfig;
    uint160 public feeGrowthGlobal0X128;
    uint160 public feeGrowthGlobal1X128;
    
    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
        sqrtPriceX96 = 79228162514264337593543950336; // sqrt(1) * 2^96
        tick = 0;
        fee = 3000;
    }
    
    function setPlugin(address _plugin) external {
        plugin = _plugin;
    }
    
    function setPluginConfig(uint8 newPluginConfig) external {
        pluginConfig = newPluginConfig;
    }
    
    function globalState() external view returns (uint160, int24, uint16, uint8, uint160, uint160) {
        return (sqrtPriceX96, tick, fee, pluginConfig, feeGrowthGlobal0X128, feeGrowthGlobal1X128);
    }
    
    function getState() external view returns (uint160, int24, uint16, uint8) {
        return (sqrtPriceX96, tick, fee, pluginConfig);
    }
    
    function updateTick(int24 newTick) external {
        tick = newTick;
    }
    
    function updateFee(uint16 newFee) external {
        fee = newFee;
    }
}

contract MockAlgebraFactory {
    mapping(address => bool) public isPool;
    
    function setPool(address pool, bool status) external {
        isPool[pool] = status;
    }
}

contract MockReflexRouter is IReflexRouter {
    struct TriggerBackrunCall {
        bytes32 triggerPoolId;
        uint112 swapAmountIn;
        bool token0In;
        address recipient;
    }
    
    TriggerBackrunCall[] public triggerBackrunCalls;
    bool public shouldRevert;
    uint256 public profitAmount;
    address public profitToken;
    address public reflexAdmin;
    
    constructor() {
        reflexAdmin = msg.sender;
        profitToken = address(0);
    }
    
    function setProfit(uint256 _profitAmount, address _profitToken) external {
        profitAmount = _profitAmount;
        profitToken = _profitToken;
    }
    
    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }
    
    function setReflexAdmin(address _admin) external {
        reflexAdmin = _admin;
    }
    
    function triggerBackrun(
        bytes32 triggerPoolId,
        uint112 swapAmountIn,
        bool token0In,
        address recipient
    ) external returns (uint256 profit, address _profitToken) {
        if (shouldRevert) {
            revert("MockRouter: Backrun failed");
        }
        
        triggerBackrunCalls.push(TriggerBackrunCall({
            triggerPoolId: triggerPoolId,
            swapAmountIn: swapAmountIn,
            token0In: token0In,
            recipient: recipient
        }));
        
        // Transfer the profit tokens to the recipient (plugin)
        if (profitAmount > 0 && profitToken != address(0)) {
            MockToken(profitToken).transfer(recipient, profitAmount);
        }
        
        return (profitAmount, profitToken);
    }
    
    function getReflexAdmin() external view returns (address) {
        return reflexAdmin;
    }
    
    function getTriggerBackrunCallsLength() external view returns (uint256) {
        return triggerBackrunCalls.length;
    }
    
    function getTriggerBackrunCall(uint256 index) external view returns (TriggerBackrunCall memory) {
        return triggerBackrunCalls[index];
    }
    
    function clearTriggerBackrunCalls() external {
        delete triggerBackrunCalls;
    }
    
    function getBackrunCallsLength() external view returns (uint256) {
        return triggerBackrunCalls.length;
    }
    
    function getBackrunCall(uint256 index) external view returns (TriggerBackrunCall memory) {
        return triggerBackrunCalls[index];
    }
    
    function clearBackrunCalls() external {
        delete triggerBackrunCalls;
    }
}

contract AlgebraBasePluginV3Test is Test {
    using TestUtils for *;
    AlgebraBasePluginV3 public plugin;
    MockAlgebraPool public pool;
    MockAlgebraFactory public factory;
    MockReflexRouter public reflexRouter;
    address public pluginFactory;
    
    address public token0;
    address public token1;
    address public recipient;
    address public admin;
    
    uint16 public constant BASE_FEE = 500;
    
    event AfterSwapCalled(
        bytes32 indexed triggerPoolId,
        int256 amount0Out,
        int256 amount1Out,
        bool zeroToOne,
        address recipient
    );
    
    function setUp() public {
        admin = makeAddr("admin");
        recipient = makeAddr("recipient");
        pluginFactory = makeAddr("pluginFactory");
        
        // Create mock tokens
        token0 = address(TestUtils.createMockToken("Token0", "T0", 1000000e18));
        token1 = address(TestUtils.createMockToken("Token1", "T1", 1000000e18));
        
        // Create mock contracts
        pool = new MockAlgebraPool(token0, token1);
        factory = new MockAlgebraFactory();
        reflexRouter = new MockReflexRouter();
        
        // Set pool in factory
        factory.setPool(address(pool), true);
        
        // Create plugin
        vm.prank(pluginFactory);
        plugin = new AlgebraBasePluginV3(
            address(pool),
            address(factory),
            pluginFactory,
            BASE_FEE,
            address(reflexRouter)
        );
        
        // Set plugin in pool
        pool.setPlugin(address(plugin));
    }
    
    // ===== AfterSwap Hook Tests =====
    
    function test_AfterSwap_BasicFunctionality() public {
        int256 amount0Out = 1000e18;
        int256 amount1Out = -500e18;
        bool zeroToOne = true;
        
        vm.prank(address(pool));
        bytes4 selector = plugin.afterSwap(
            address(0), // sender
            recipient,
            zeroToOne,
            0, // amountSpecified
            0, // sqrtPriceX96After
            amount0Out,
            amount1Out,
            ""
        );
        
        assertEq(selector, IAlgebraPlugin.afterSwap.selector);
        
        // Verify reflexAfterSwap was called
        assertEq(reflexRouter.getTriggerBackrunCallsLength(), 1);
        
        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.triggerPoolId, bytes32(uint256(uint160(address(pool)))));
        assertEq(call.swapAmountIn, uint112(uint256(amount0Out > 0 ? amount0Out : amount1Out)));
        assertEq(call.token0In, zeroToOne);
        assertEq(call.recipient, address(plugin));
    }
    
    function test_AfterSwap_OnlyPoolCanCall() public {
        vm.expectRevert();
        plugin.afterSwap(
            address(0),
            recipient,
            true,
            0,
            0,
            1000e18,
            -500e18,
            ""
        );
    }
    
    function test_AfterSwap_ZeroToOneFalse() public {
        int256 amount0Out = -1000e18;
        int256 amount1Out = 500e18;
        bool zeroToOne = false;
        
        vm.prank(address(pool));
        plugin.afterSwap(
            address(0),
            recipient,
            zeroToOne,
            0,
            0,
            amount0Out,
            amount1Out,
            ""
        );
        
        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.token0In, false);
        assertEq(call.swapAmountIn, uint112(uint256(amount1Out)));
        assertEq(call.recipient, address(plugin));
    }
    
    function test_AfterSwap_WithDifferentRecipients() public {
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");
        
        // First swap
        vm.prank(address(pool));
        plugin.afterSwap(address(0), recipient1, true, 0, 0, 1000e18, -500e18, "");
        
        // Second swap
        vm.prank(address(pool));
        plugin.afterSwap(address(0), recipient2, false, 0, 0, -800e18, 400e18, "");
        
        assertEq(reflexRouter.getTriggerBackrunCallsLength(), 2);
        
        MockReflexRouter.TriggerBackrunCall memory call1 = reflexRouter.getTriggerBackrunCall(0);
        MockReflexRouter.TriggerBackrunCall memory call2 = reflexRouter.getTriggerBackrunCall(1);
        
        assertEq(call1.recipient, address(plugin));
        assertEq(call2.recipient, address(plugin));
    }
    
    function test_AfterSwap_LargeAmounts() public {
        int256 amount0Out = type(int128).max;
        int256 amount1Out = type(int128).min;
        
        vm.prank(address(pool));
        plugin.afterSwap(
            address(0),
            recipient,
            true,
            0,
            0,
            amount0Out,
            amount1Out,
            ""
        );
        
        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.swapAmountIn, uint112(uint256(amount0Out)));
        assertEq(call.token0In, true);
    }
    
    function test_AfterSwap_ZeroAmounts() public {
        vm.prank(address(pool));
        plugin.afterSwap(
            address(0),
            recipient,
            true,
            0,
            0,
            0, // amount0Out
            0, // amount1Out
            ""
        );
        
        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.swapAmountIn, 0);
        assertEq(call.token0In, true);
    }
    
    // ===== ReflexAfterSwap Integration Tests =====
    
    function test_ReflexAfterSwap_Integration() public {
        // Setup: Give the router some tokens to return as profit
        MockToken profitToken = MockToken(token0);
        profitToken.mint(address(reflexRouter), 1000e18);
        
        reflexRouter.setProfit(1000e18, token0);
        
        vm.prank(address(pool));
        plugin.afterSwap(
            address(0),
            recipient,
            true,
            0,
            0,
            1000e18,
            -500e18,
            ""
        );
        
        // Verify the backrun was called with correct parameters
        assertEq(reflexRouter.getTriggerBackrunCallsLength(), 1);
        
        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.triggerPoolId, bytes32(uint256(uint160(address(pool)))));
    }
    
    function test_ReflexAfterSwap_RouterFailure() public {
        reflexRouter.setShouldRevert(true);
        
        // Should not revert even if router fails - this is the failsafe behavior
        vm.prank(address(pool));
        plugin.afterSwap(
            address(0),
            recipient,
            true,
            0,
            0,
            1000e18,
            -500e18,
            ""
        );
        
        // Router call should have been attempted but failed gracefully
        // No backrun calls should be recorded due to the failsafe catch block
        assertEq(reflexRouter.getTriggerBackrunCallsLength(), 0);
    }
    
    function test_ReflexAfterSwap_MultipleSwaps() public {
        // Setup: Give the router some tokens to return as profit
        MockToken profitToken = MockToken(token0);
        profitToken.mint(address(reflexRouter), 2000e18); // Enough for multiple swaps
        
        reflexRouter.setProfit(500e18, token0);
        
        // First swap
        vm.prank(address(pool));
        plugin.afterSwap(address(0), recipient, true, 0, 0, 1000e18, -500e18, "");
        
        // Second swap
        vm.prank(address(pool));
        plugin.afterSwap(address(0), recipient, false, 0, 0, -800e18, 400e18, "");
        
        // Third swap
        vm.prank(address(pool));
        plugin.afterSwap(address(0), recipient, true, 0, 0, 200e18, -100e18, "");
        
        assertEq(reflexRouter.getTriggerBackrunCallsLength(), 3);
        
        // Verify each call has unique parameters
        MockReflexRouter.TriggerBackrunCall memory call1 = reflexRouter.getTriggerBackrunCall(0);
        MockReflexRouter.TriggerBackrunCall memory call2 = reflexRouter.getTriggerBackrunCall(1);
        MockReflexRouter.TriggerBackrunCall memory call3 = reflexRouter.getTriggerBackrunCall(2);
        
        assertEq(call1.token0In, true);
        assertEq(call2.token0In, false);
        assertEq(call3.token0In, true);
        
        assertEq(call1.swapAmountIn, 1000e18);
        assertEq(call2.swapAmountIn, 400e18);
        assertEq(call3.swapAmountIn, 200e18);
    }
    
    // ===== Fuzz Tests =====
    
    function testFuzz_AfterSwap(
        int256 amount0Out,
        int256 amount1Out,
        bool zeroToOne,
        address fuzzRecipient
    ) public {
        vm.assume(fuzzRecipient != address(0));
        
        vm.prank(address(pool));
        bytes4 selector = plugin.afterSwap(
            address(0),
            fuzzRecipient,
            zeroToOne,
            0,
            0,
            amount0Out,
            amount1Out,
            ""
        );
        
        assertEq(selector, IAlgebraPlugin.afterSwap.selector);
        
        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        uint256 expectedSwapAmount = uint256(amount0Out > 0 ? amount0Out : amount1Out);
        assertEq(call.swapAmountIn, uint112(expectedSwapAmount));
        assertEq(call.token0In, zeroToOne);
        assertEq(call.recipient, address(plugin));
    }
    
    function testFuzz_TriggerPoolId(address poolAddress) public {
        vm.assume(poolAddress != address(0));
        
        // Create a new plugin with different pool
        MockAlgebraPool newPool = new MockAlgebraPool(token0, token1);
        factory.setPool(address(newPool), true);
        
        vm.prank(pluginFactory);
        AlgebraBasePluginV3 newPlugin = new AlgebraBasePluginV3(
            address(newPool),
            address(factory),
            pluginFactory,
            BASE_FEE,
            address(reflexRouter)
        );
        
        newPool.setPlugin(address(newPlugin));
        
        vm.prank(address(newPool));
        newPlugin.afterSwap(address(0), recipient, true, 0, 0, 1000e18, -500e18, "");
        
        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.triggerPoolId, bytes32(uint256(uint160(address(newPool)))));
    }
    
    // ===== Edge Cases =====
    
    function test_AfterSwap_MaxValues() public {
        vm.prank(address(pool));
        plugin.afterSwap(
            address(0),
            recipient,
            true,
            type(int256).max,
            type(uint160).max,
            type(int256).max,
            type(int256).min,
            "0xffffffff"
        );
        
        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.swapAmountIn, uint112(uint256(type(int256).max)));
        assertEq(call.token0In, true);
    }
    
    function test_AfterSwap_EmptyCalldata() public {
        vm.prank(address(pool));
        plugin.afterSwap(
            address(0),
            recipient,
            true,
            0,
            0,
            1000e18,
            -500e18,
            ""
        );
        
        assertEq(reflexRouter.getTriggerBackrunCallsLength(), 1);
    }
    
    function test_AfterSwap_ReturnsCorrectSelector() public {
        vm.prank(address(pool));
        bytes4 returnedSelector = plugin.afterSwap(
            address(0),
            recipient,
            true,
            0,
            0,
            1000e18,
            -500e18,
            ""
        );
        
        assertEq(returnedSelector, IAlgebraPlugin.afterSwap.selector);
        assertEq(returnedSelector, bytes4(keccak256("afterSwap(address,address,bool,int256,uint160,int256,int256,bytes)")));
    }
    
    // ===== State Consistency Tests =====
    
    function test_StateConsistency_MultipleSwaps() public {
        // Record initial state
        uint256 initialCallCount = reflexRouter.getTriggerBackrunCallsLength();
        
        // Perform multiple swaps
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(address(pool));
            plugin.afterSwap(
                address(0),
                recipient,
                i % 2 == 0, // alternate zeroToOne
                0,
                0,
                int256(1000e18 + i),
                int256(-500e18 - int256(i)),
                ""
            );
        }
        
        // Verify all swaps were recorded
        assertEq(reflexRouter.getTriggerBackrunCallsLength(), initialCallCount + 5);
        
        // Verify each swap has correct sequential data
        for (uint256 i = 0; i < 5; i++) {
            MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(i);
            assertEq(call.token0In, i % 2 == 0);
            assertEq(call.swapAmountIn, uint112(1000e18 + i));
        }
    }
}
