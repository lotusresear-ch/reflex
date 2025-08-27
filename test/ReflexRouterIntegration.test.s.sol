// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ReflexRouter.sol";
import "../src/interfaces/IReflexQuoter.sol";
import "../src/libraries/DexTypes.sol";
import "./utils/TestUtils.sol";
import "./mocks/MockToken.sol";

// Comprehensive mock quoter for integration testing
contract FullMockQuoter is IReflexQuoter {
    struct RouteConfig {
        uint256 profit;
        address[] pools;
        uint8[] dexTypes;
        uint8[] dexMeta;
        address[] tokens;
        uint256[] amounts;
        uint256 initialHopIndex;
        bool exists;
    }

    mapping(bytes32 => RouteConfig) public routes;
    uint256 public callCount;

    function addRoute(
        address pool,
        uint8 assetId,
        uint256 swapAmountIn,
        uint256 profit,
        address[] memory pools,
        uint8[] memory dexTypes,
        uint8[] memory dexMeta,
        address[] memory tokens,
        uint256[] memory amounts,
        uint256 initialHopIndex
    ) external {
        bytes32 key = keccak256(abi.encodePacked(pool, assetId, swapAmountIn));
        routes[key] = RouteConfig({
            profit: profit,
            pools: pools,
            dexTypes: dexTypes,
            dexMeta: dexMeta,
            tokens: tokens,
            amounts: amounts,
            initialHopIndex: initialHopIndex,
            exists: true
        });
    }

    function getQuote(address pool, uint8 assetId, uint256 swapAmountIn)
        external
        override
        returns (uint256 profit, SwapDecodedData memory decoded, uint256[] memory amountsOut, uint256 initialHopIndex)
    {
        callCount++;
        bytes32 key = keccak256(abi.encodePacked(pool, assetId, swapAmountIn));
        RouteConfig memory route = routes[key];

        if (!route.exists) {
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

        return (
            route.profit,
            SwapDecodedData({
                pools: route.pools,
                dexType: route.dexTypes,
                dexMeta: route.dexMeta,
                amount: uint112(swapAmountIn),
                tokens: route.tokens
            }),
            route.amounts,
            route.initialHopIndex
        );
    }

    function getCallCount() external view returns (uint256) {
        return callCount;
    }
}

// Full featured mock DEX pools for integration testing
contract IntegrationMockV2Pool {
    address public token0;
    address public token1;
    uint256 public reserve0;
    uint256 public reserve1;

    mapping(address => bool) public authorizedCallers;

    constructor(address _token0, address _token1, uint256 _reserve0, uint256 _reserve1) {
        token0 = _token0;
        token1 = _token1;
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }

    function setAuthorizedCaller(address caller, bool authorized) external {
        authorizedCallers[caller] = authorized;
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external {
        require(authorizedCallers[msg.sender] || msg.sender == to, "Unauthorized");

        // Simulate constant product formula with 0.3% fee
        if (amount0Out > 0) {
            require(amount0Out <= reserve0, "Insufficient liquidity");
            MockToken(token0).mint(to, amount0Out);
            reserve0 -= amount0Out;
        }

        if (amount1Out > 0) {
            require(amount1Out <= reserve1, "Insufficient liquidity");
            MockToken(token1).mint(to, amount1Out);
            reserve1 -= amount1Out;
        }

        // Callback for flash loan
        if (data.length > 0) {
            (bool success,) =
                to.call(abi.encodeWithSignature("swap(uint256,uint256,bytes)", amount0Out, amount1Out, data));
            require(success, "Callback failed");
        }

        // Update reserves after callback (simplified)
        reserve0 = MockToken(token0).balanceOf(address(this));
        reserve1 = MockToken(token1).balanceOf(address(this));
    }
}

contract IntegrationMockV3Pool {
    address public token0;
    address public token1;
    uint256 public price; // Simplified price representation

    mapping(address => bool) public authorizedCallers;

    constructor(address _token0, address _token1, uint256 _price) {
        token0 = _token0;
        token1 = _token1;
        price = _price;
    }

    function setAuthorizedCaller(address caller, bool authorized) external {
        authorizedCallers[caller] = authorized;
    }

    function setPrice(uint256 _price) external {
        price = _price;
    }

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1) {
        require(authorizedCallers[msg.sender] || msg.sender == recipient, "Unauthorized");

        uint256 amountIn = uint256(amountSpecified);

        // Simulate swap with price impact and fees
        if (zeroForOne) {
            amount0 = amountSpecified;
            uint256 amountOut = (amountIn * price) / 1e18 * 997 / 1000; // 0.3% fee
            amount1 = -int256(amountOut);
            MockToken(token1).mint(recipient, amountOut);
        } else {
            amount1 = amountSpecified;
            uint256 amountOut = (amountIn * 1e18) / price * 997 / 1000; // 0.3% fee
            amount0 = -int256(amountOut);
            MockToken(token0).mint(recipient, amountOut);
        }

        // Callback
        if (data.length > 0) {
            (bool success,) =
                recipient.call(abi.encodeWithSignature("swap(int256,int256,bytes)", amount0, amount1, data));
            require(success, "Callback failed");
        }
    }
}

contract ReflexRouterIntegrationTest is Test {
    using TestUtils for *;

    // Events
    event BackrunExecuted(
        bytes32 indexed triggerPoolId,
        uint112 swapAmountIn,
        bool token0In,
        uint256 profit,
        address profitToken,
        address indexed recipient
    );

    ReflexRouter public reflexRouter;
    FullMockQuoter public quoter;

    MockToken public tokenA;
    MockToken public tokenB;
    MockToken public tokenC;
    MockToken public tokenD;

    IntegrationMockV2Pool public poolAB_V2;
    IntegrationMockV3Pool public poolBC_V3;
    IntegrationMockV2Pool public poolCA_V2;
    IntegrationMockV3Pool public poolAD_V3;

    address public owner = address(0x1);
    address public trader = address(0x2);
    address public recipient = address(0x3);

    function setUp() public {
        // Deploy router
        vm.prank(owner);
        reflexRouter = new ReflexRouter();

        // Deploy quoter
        quoter = new FullMockQuoter();

        vm.prank(owner);
        reflexRouter.setReflexQuoter(address(quoter));

        // Deploy tokens
        tokenA = new MockToken("TokenA", "TKA", 1000000 * 10 ** 18);
        tokenB = new MockToken("TokenB", "TKB", 1000000 * 10 ** 18);
        tokenC = new MockToken("TokenC", "TKC", 1000000 * 10 ** 18);
        tokenD = new MockToken("TokenD", "TKD", 1000000 * 10 ** 18);

        // Deploy pools with realistic reserves
        poolAB_V2 = new IntegrationMockV2Pool(address(tokenA), address(tokenB), 100000 * 10 ** 18, 95000 * 10 ** 18);

        poolBC_V3 = new IntegrationMockV3Pool(
            address(tokenB),
            address(tokenC),
            1050000000000000000 // 1.05 TKC per TKB
        );

        poolCA_V2 = new IntegrationMockV2Pool(address(tokenC), address(tokenA), 90000 * 10 ** 18, 95000 * 10 ** 18);

        poolAD_V3 = new IntegrationMockV3Pool(
            address(tokenA),
            address(tokenD),
            2000000000000000000 // 2 TKD per TKA
        );

        // Authorize router to interact with pools
        poolAB_V2.setAuthorizedCaller(address(reflexRouter), true);
        poolBC_V3.setAuthorizedCaller(address(reflexRouter), true);
        poolCA_V2.setAuthorizedCaller(address(reflexRouter), true);
        poolAD_V3.setAuthorizedCaller(address(reflexRouter), true);

        // Fund pools with tokens
        tokenA.mint(address(poolAB_V2), 100000 * 10 ** 18);
        tokenB.mint(address(poolAB_V2), 95000 * 10 ** 18);

        tokenB.mint(address(poolBC_V3), 100000 * 10 ** 18);
        tokenC.mint(address(poolBC_V3), 105000 * 10 ** 18);

        tokenC.mint(address(poolCA_V2), 90000 * 10 ** 18);
        tokenA.mint(address(poolCA_V2), 95000 * 10 ** 18);

        tokenA.mint(address(poolAD_V3), 50000 * 10 ** 18);
        tokenD.mint(address(poolAD_V3), 100000 * 10 ** 18);

        // Fund router with tokens for testing
        tokenA.mint(address(reflexRouter), 10000 * 10 ** 18);
        tokenB.mint(address(reflexRouter), 10000 * 10 ** 18);
        tokenC.mint(address(reflexRouter), 10000 * 10 ** 18);
        tokenD.mint(address(reflexRouter), 10000 * 10 ** 18);
    }

    // =============================================================================
    // Basic Integration Tests
    // =============================================================================

    function test_simple_two_hop_arbitrage() public {
        // A -> B -> A arbitrage
        uint256 swapAmount = 1000 * 10 ** 18;
        uint256 expectedProfit = 50 * 10 ** 18;

        // Set up route: poolAB_V2 -> poolCA_V2 (via B->C->A)
        address[] memory pools = new address[](2);
        pools[0] = address(poolAB_V2);
        pools[1] = address(poolCA_V2);

        uint8[] memory dexTypes = new uint8[](2);
        dexTypes[0] = DexTypes.UNISWAP_V2_WITH_CALLBACK;
        dexTypes[1] = DexTypes.UNISWAP_V2_WITH_CALLBACK;

        uint8[] memory dexMeta = new uint8[](2);
        dexMeta[0] = 0x80; // A -> B (zeroForOne = true)
        dexMeta[1] = 0x00; // C -> A (zeroForOne = false)

        address[] memory tokens = new address[](3);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        tokens[2] = address(tokenA);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = swapAmount;
        amounts[1] = swapAmount * 95 / 100; // After 5% slippage
        amounts[2] = swapAmount + expectedProfit;

        quoter.addRoute(
            address(poolAB_V2),
            0, // tokenA is asset 0
            swapAmount,
            expectedProfit,
            pools,
            dexTypes,
            dexMeta,
            tokens,
            amounts,
            0
        );

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));
        uint256 initialBalance = tokenA.balanceOf(recipient);

        (uint256 profit, address profitToken) = reflexRouter.triggerBackrun(
            triggerPoolId,
            uint112(swapAmount),
            true, // token0In (tokenA)
            recipient
        );

        assertEq(profit, expectedProfit);
        assertEq(profitToken, address(tokenA));
        assertEq(tokenA.balanceOf(recipient), initialBalance + expectedProfit);
    }

    function test_three_hop_arbitrage_mixed_dex() public {
        // A -> B -> C -> A arbitrage using mixed DEX types
        uint256 swapAmount = 2000 * 10 ** 18;
        uint256 expectedProfit = 100 * 10 ** 18;

        address[] memory pools = new address[](3);
        pools[0] = address(poolAB_V2); // V2
        pools[1] = address(poolBC_V3); // V3
        pools[2] = address(poolCA_V2); // V2

        uint8[] memory dexTypes = new uint8[](3);
        dexTypes[0] = DexTypes.UNISWAP_V2_WITH_CALLBACK;
        dexTypes[1] = DexTypes.UNISWAP_V3;
        dexTypes[2] = DexTypes.UNISWAP_V2_WITH_CALLBACK;

        uint8[] memory dexMeta = new uint8[](3);
        dexMeta[0] = 0x80; // A -> B
        dexMeta[1] = 0x80; // B -> C
        dexMeta[2] = 0x00; // C -> A

        address[] memory tokens = new address[](4);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        tokens[2] = address(tokenC);
        tokens[3] = address(tokenA);

        uint256[] memory amounts = new uint256[](4);
        amounts[0] = swapAmount;
        amounts[1] = swapAmount * 95 / 100;
        amounts[2] = swapAmount * 90 / 100;
        amounts[3] = swapAmount + expectedProfit;

        quoter.addRoute(address(poolAB_V2), 0, swapAmount, expectedProfit, pools, dexTypes, dexMeta, tokens, amounts, 0);

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));
        uint256 initialBalance = tokenA.balanceOf(recipient);

        (uint256 profit, address profitToken) =
            reflexRouter.triggerBackrun(triggerPoolId, uint112(swapAmount), true, recipient);

        assertEq(profit, expectedProfit);
        assertEq(profitToken, address(tokenA));
        assertEq(tokenA.balanceOf(recipient), initialBalance + expectedProfit);
    }

    // =============================================================================
    // Performance Tests
    // =============================================================================

    function test_gas_usage_simple_arbitrage() public {
        uint256 swapAmount = 1000 * 10 ** 18;

        address[] memory pools = new address[](2);
        pools[0] = address(poolAB_V2);
        pools[1] = address(poolCA_V2);

        uint8[] memory dexTypes = new uint8[](2);
        dexTypes[0] = DexTypes.UNISWAP_V2_WITH_CALLBACK;
        dexTypes[1] = DexTypes.UNISWAP_V2_WITH_CALLBACK;

        uint8[] memory dexMeta = new uint8[](2);
        dexMeta[0] = 0x80;
        dexMeta[1] = 0x00;

        address[] memory tokens = new address[](3);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        tokens[2] = address(tokenA);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = swapAmount;
        amounts[1] = swapAmount * 95 / 100;
        amounts[2] = swapAmount * 105 / 100;

        quoter.addRoute(
            address(poolAB_V2), 0, swapAmount, swapAmount * 5 / 100, pools, dexTypes, dexMeta, tokens, amounts, 0
        );

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));

        uint256 gasBefore = gasleft();
        reflexRouter.triggerBackrun(triggerPoolId, uint112(swapAmount), true, recipient);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas used for 2-hop arbitrage", gasUsed);

        // Should be reasonable gas usage (under 500k)
        assertLt(gasUsed, 500000);
    }

    function test_gas_usage_complex_arbitrage() public {
        uint256 swapAmount = 1000 * 10 ** 18;

        // 4-hop arbitrage
        address[] memory pools = new address[](4);
        pools[0] = address(poolAB_V2);
        pools[1] = address(poolBC_V3);
        pools[2] = address(poolCA_V2);
        pools[3] = address(poolAD_V3);

        uint8[] memory dexTypes = new uint8[](4);
        dexTypes[0] = DexTypes.UNISWAP_V2_WITH_CALLBACK;
        dexTypes[1] = DexTypes.UNISWAP_V3;
        dexTypes[2] = DexTypes.UNISWAP_V2_WITH_CALLBACK;
        dexTypes[3] = DexTypes.UNISWAP_V3;

        uint8[] memory dexMeta = new uint8[](4);
        dexMeta[0] = 0x80;
        dexMeta[1] = 0x80;
        dexMeta[2] = 0x00;
        dexMeta[3] = 0x00;

        address[] memory tokens = new address[](5);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        tokens[2] = address(tokenC);
        tokens[3] = address(tokenA);
        tokens[4] = address(tokenD);

        uint256[] memory amounts = new uint256[](5);
        amounts[0] = swapAmount;
        amounts[1] = swapAmount * 95 / 100;
        amounts[2] = swapAmount * 90 / 100;
        amounts[3] = swapAmount * 95 / 100;
        amounts[4] = swapAmount * 105 / 100;

        quoter.addRoute(
            address(poolAB_V2), 0, swapAmount, swapAmount * 5 / 100, pools, dexTypes, dexMeta, tokens, amounts, 0
        );

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));

        uint256 gasBefore = gasleft();
        reflexRouter.triggerBackrun(triggerPoolId, uint112(swapAmount), true, recipient);
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas used for 4-hop arbitrage", gasUsed);

        // Should still be reasonable for complex arbitrage (under 800k)
        assertLt(gasUsed, 800000);
    }

    // =============================================================================
    // Stress Tests
    // =============================================================================

    function test_multiple_sequential_arbitrages() public {
        uint256 swapAmount = 500 * 10 ** 18;

        // Set up a profitable route
        address[] memory pools = new address[](2);
        pools[0] = address(poolAB_V2);
        pools[1] = address(poolCA_V2);

        uint8[] memory dexTypes = new uint8[](2);
        dexTypes[0] = DexTypes.UNISWAP_V2_WITH_CALLBACK;
        dexTypes[1] = DexTypes.UNISWAP_V2_WITH_CALLBACK;

        uint8[] memory dexMeta = new uint8[](2);
        dexMeta[0] = 0x80;
        dexMeta[1] = 0x00;

        address[] memory tokens = new address[](3);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        tokens[2] = address(tokenA);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = swapAmount;
        amounts[1] = swapAmount * 95 / 100;
        amounts[2] = swapAmount * 102 / 100; // 2% profit

        quoter.addRoute(
            address(poolAB_V2), 0, swapAmount, swapAmount * 2 / 100, pools, dexTypes, dexMeta, tokens, amounts, 0
        );

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));
        uint256 totalProfit = 0;

        // Execute 10 arbitrages sequentially
        for (uint256 i = 0; i < 10; i++) {
            (uint256 profit,) = reflexRouter.triggerBackrun(triggerPoolId, uint112(swapAmount), true, recipient);
            totalProfit += profit;
        }

        // Should have accumulated profit
        assertGt(totalProfit, 0);
        emit log_named_uint("Total profit from 10 arbitrages", totalProfit);
    }

    function test_rapid_fire_arbitrages() public {
        uint256 swapAmount = 100 * 10 ** 18;

        address[] memory pools = new address[](2);
        pools[0] = address(poolAB_V2);
        pools[1] = address(poolCA_V2);

        uint8[] memory dexTypes = new uint8[](2);
        dexTypes[0] = DexTypes.UNISWAP_V2_WITH_CALLBACK;
        dexTypes[1] = DexTypes.UNISWAP_V2_WITH_CALLBACK;

        uint8[] memory dexMeta = new uint8[](2);
        dexMeta[0] = 0x80;
        dexMeta[1] = 0x00;

        address[] memory tokens = new address[](3);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        tokens[2] = address(tokenA);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = swapAmount;
        amounts[1] = swapAmount * 99 / 100;
        amounts[2] = swapAmount * 101 / 100; // 1% profit

        quoter.addRoute(
            address(poolAB_V2), 0, swapAmount, swapAmount / 100, pools, dexTypes, dexMeta, tokens, amounts, 0
        );

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));

        uint256 gasBefore = gasleft();

        // Execute 5 rapid arbitrages
        for (uint256 i = 0; i < 5; i++) {
            reflexRouter.triggerBackrun(triggerPoolId, uint112(swapAmount), true, recipient);
        }

        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas used for 5 rapid arbitrages", gasUsed);

        // Verify quoter was called 5 times
        assertEq(quoter.getCallCount(), 5);
    }

    // =============================================================================
    // Real-world Scenario Tests
    // =============================================================================

    function test_arbitrage_with_price_impact() public {
        // Simulate arbitrage with realistic price impact
        uint256 swapAmount = 5000 * 10 ** 18; // Large trade

        // Update pool to reflect price impact
        poolBC_V3.setPrice(1100000000000000000); // Price increases due to large trade

        address[] memory pools = new address[](3);
        pools[0] = address(poolAB_V2);
        pools[1] = address(poolBC_V3);
        pools[2] = address(poolCA_V2);

        uint8[] memory dexTypes = new uint8[](3);
        dexTypes[0] = DexTypes.UNISWAP_V2_WITH_CALLBACK;
        dexTypes[1] = DexTypes.UNISWAP_V3;
        dexTypes[2] = DexTypes.UNISWAP_V2_WITH_CALLBACK;

        uint8[] memory dexMeta = new uint8[](3);
        dexMeta[0] = 0x80;
        dexMeta[1] = 0x80;
        dexMeta[2] = 0x00;

        address[] memory tokens = new address[](4);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        tokens[2] = address(tokenC);
        tokens[3] = address(tokenA);

        // Amounts reflecting price impact
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = swapAmount;
        amounts[1] = swapAmount * 90 / 100; // Higher slippage
        amounts[2] = swapAmount * 85 / 100; // Even higher due to price impact
        amounts[3] = swapAmount * 87 / 100; // Some recovery but still a loss

        quoter.addRoute(
            address(poolAB_V2),
            0,
            swapAmount,
            0, // No profit due to price impact
            pools,
            dexTypes,
            dexMeta,
            tokens,
            amounts,
            0
        );

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));

        (uint256 profit, address profitToken) =
            reflexRouter.triggerBackrun(triggerPoolId, uint112(swapAmount), true, recipient);

        // Should return no profit due to price impact
        assertEq(profit, 0);
        assertEq(profitToken, address(0));
    }

    function test_arbitrage_opportunity_disappears() public {
        // Test scenario where arbitrage opportunity disappears between quote and execution
        uint256 swapAmount = 1000 * 10 ** 18;

        // Initially profitable route
        address[] memory pools = new address[](2);
        pools[0] = address(poolAB_V2);
        pools[1] = address(poolCA_V2);

        uint8[] memory dexTypes = new uint8[](2);
        dexTypes[0] = DexTypes.UNISWAP_V2_WITH_CALLBACK;
        dexTypes[1] = DexTypes.UNISWAP_V2_WITH_CALLBACK;

        uint8[] memory dexMeta = new uint8[](2);
        dexMeta[0] = 0x80;
        dexMeta[1] = 0x00;

        address[] memory tokens = new address[](3);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        tokens[2] = address(tokenA);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = swapAmount;
        amounts[1] = swapAmount * 95 / 100;
        amounts[2] = swapAmount * 98 / 100; // Originally profitable

        quoter.addRoute(
            address(poolAB_V2),
            0,
            swapAmount,
            0, // No profit when actually executed
            pools,
            dexTypes,
            dexMeta,
            tokens,
            amounts,
            0
        );

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));

        (uint256 profit, address profitToken) =
            reflexRouter.triggerBackrun(triggerPoolId, uint112(swapAmount), true, recipient);

        // Should handle gracefully when opportunity disappears
        assertEq(profit, 0);
        assertEq(profitToken, address(0));
    }

    // =============================================================================
    // Event Verification Tests
    // =============================================================================

    function test_event_emission_comprehensive() public {
        uint256 swapAmount = 1000 * 10 ** 18;
        uint256 expectedProfit = 50 * 10 ** 18;

        address[] memory pools = new address[](2);
        pools[0] = address(poolAB_V2);
        pools[1] = address(poolCA_V2);

        uint8[] memory dexTypes = new uint8[](2);
        dexTypes[0] = DexTypes.UNISWAP_V2_WITH_CALLBACK;
        dexTypes[1] = DexTypes.UNISWAP_V2_WITH_CALLBACK;

        uint8[] memory dexMeta = new uint8[](2);
        dexMeta[0] = 0x80;
        dexMeta[1] = 0x00;

        address[] memory tokens = new address[](3);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        tokens[2] = address(tokenA);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = swapAmount;
        amounts[1] = swapAmount * 95 / 100;
        amounts[2] = swapAmount + expectedProfit;

        quoter.addRoute(address(poolAB_V2), 0, swapAmount, expectedProfit, pools, dexTypes, dexMeta, tokens, amounts, 0);

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));

        // Expect the BackrunExecuted event
        vm.expectEmit(true, true, true, true);
        emit BackrunExecuted(triggerPoolId, uint112(swapAmount), true, expectedProfit, address(tokenA), recipient);

        reflexRouter.triggerBackrun(triggerPoolId, uint112(swapAmount), true, recipient);
    }

    // =============================================================================
    // Fuzz Testing for Integration
    // =============================================================================

    function testFuzz_arbitrage_amounts(uint112 swapAmountIn) public {
        vm.assume(swapAmountIn > 1000 && swapAmountIn < 1000000 * 10 ** 18);

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));

        (uint256 profit, address profitToken) =
            reflexRouter.triggerBackrun(triggerPoolId, swapAmountIn, true, recipient);

        // Without configured quotes, should return no profit
        assertEq(profit, 0);
        assertEq(profitToken, address(0));
    }

    function testFuzz_multiple_recipients(address _recipient) public {
        vm.assume(_recipient != address(0));
        vm.assume(_recipient.code.length == 0); // EOA only

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));

        (uint256 profit,) = reflexRouter.triggerBackrun(triggerPoolId, 1000 * 10 ** 18, true, _recipient);

        assertEq(profit, 0);
    }
}
