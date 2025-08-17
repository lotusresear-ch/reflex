// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MockPool
/// @notice Simple mock pool for basic testing scenarios
contract MockPool {
    address public token0;
    address public token1;
    address public plugin;
    address public factory;

    constructor(address _token0, address _token1, address _factory) {
        token0 = _token0;
        token1 = _token1;
        factory = _factory;
    }

    function setPlugin(address _plugin) external {
        plugin = _plugin;
    }

    function setFactory(address _factory) external {
        factory = _factory;
    }
}
