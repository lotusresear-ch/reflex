// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ReflexRouter.sol";
import "../src/interfaces/IReflexRouter.sol";
import "../src/interfaces/IReflexQuoter.sol";
import "../src/libraries/DexTypes.sol";
import "./mocks/MockToken.sol";

contract BasicReflexRouterTest is Test {
    ReflexRouter public reflexRouter;
    MockToken public token0;

    address public owner = address(0x1);

    function setUp() public {
        // Simple setup
        vm.prank(owner);
        reflexRouter = new ReflexRouter();
        
        token0 = new MockToken("Token0", "TK0", 1000000 * 10**18);
    }

    function test_constructor() public {
        vm.prank(owner);
        ReflexRouter newRouter = new ReflexRouter();
        // In foundry tests, tx.origin is the test runner, not the pranked address
        assertEq(newRouter.owner(), tx.origin);
        assertEq(newRouter.getReflexAdmin(), tx.origin);
        assertEq(newRouter.reflexQuoter(), address(0));
    }

    function test_setReflexQuoter_success() public {
        address newQuoter = address(0x123);
        
        // Need to prank as the actual owner (tx.origin)
        vm.prank(reflexRouter.owner());
        reflexRouter.setReflexQuoter(newQuoter);
        
        assertEq(reflexRouter.reflexQuoter(), newQuoter);
    }
}
