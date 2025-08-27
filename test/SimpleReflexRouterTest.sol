// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/ReflexRouter.sol";

contract SimpleReflexRouterTest is Test {
    function test_simple_deploy() public {
        address deployer = address(this);
        ReflexRouter router = new ReflexRouter();

        // In tests, tx.origin is typically the test contract itself
        console.log("tx.origin:", tx.origin);
        console.log("msg.sender:", msg.sender);
        console.log("address(this):", address(this));
        console.log("router.owner():", router.owner());

        // The owner should be set to tx.origin from constructor
        assertEq(router.owner(), tx.origin);
    }
}
