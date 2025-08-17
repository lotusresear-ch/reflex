// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@reflex/interfaces/IReflexRouter.sol";
import "./MockToken.sol";

/// @title MockReflexRouter
/// @notice Mock implementation of IReflexRouter for testing
contract MockReflexRouter is IReflexRouter {
    struct TriggerBackrunCall {
        bytes32 triggerPoolId;
        uint112 swapAmountIn;
        bool token0In;
        address recipient;
    }

    TriggerBackrunCall[] public triggerBackrunCalls;
    address public reflexAdmin;
    MockToken public profitToken;
    uint256 public mockProfit;
    bool public shouldRevert;

    constructor(address _admin, address _profitToken) {
        reflexAdmin = _admin;
        if (_profitToken != address(0)) {
            profitToken = MockToken(_profitToken);
        }
        mockProfit = 1000 * 10 ** 18; // Default 1000 tokens profit
    }

    function getReflexAdmin() external view override returns (address) {
        return reflexAdmin;
    }

    function setMockProfit(uint256 _profit) external {
        mockProfit = _profit;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function setReflexAdmin(address _admin) external {
        reflexAdmin = _admin;
    }

    function setProfitToken(address _profitToken) external {
        profitToken = MockToken(_profitToken);
        // Mint tokens to this router so it can transfer them
        if (_profitToken != address(0)) {
            profitToken.mint(address(this), 10000000 * 10 ** 18);
        }
    }

    function triggerBackrun(bytes32 triggerPoolId, uint112 swapAmountIn, bool token0In, address recipient)
        external
        override
        returns (uint256 profit, address _profitToken)
    {
        if (shouldRevert) {
            revert("Mock router reverted");
        }

        triggerBackrunCalls.push(
            TriggerBackrunCall({
                triggerPoolId: triggerPoolId,
                swapAmountIn: swapAmountIn,
                token0In: token0In,
                recipient: recipient
            })
        );

        // Transfer the profit tokens to the recipient if configured
        if (mockProfit > 0 && address(profitToken) != address(0)) {
            profitToken.transfer(recipient, mockProfit);
        }

        return (mockProfit, address(profitToken));
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
}
