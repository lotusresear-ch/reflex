// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "../interfaces/IReflexRouter.sol";
import "./FundsSplitter/FundsSplitter.sol";

abstract contract ReflexAfterSwap is FundsSplitter {
    address router;
    address reflexAdmin;
    bool private locked;

    constructor(address _router) {
        require(_router != address(0), "Invalid router address");
        router = _router;
        reflexAdmin = IReflexRouter(_router).getReflexAdmin();
    }

    modifier onlyReflexAdmin() {
        _onlyAdmin();
        _;
    }

    modifier nonReentrant() {
        if (locked) {
            return;
        }
        locked = true;
        _;
        locked = false;
    }

    function _onlyAdmin() internal view virtual override {
        require(msg.sender == reflexAdmin, "Caller is not the reflex admin");
    }

    /// @notice Set the Reflex router address
    /// @param _router The address of the Reflex router
    function setReflexRouter(address _router) external onlyReflexAdmin {
        require(_router != address(0), "Invalid router address");
        router = _router;
        reflexAdmin = IReflexRouter(_router).getReflexAdmin();
    }

    /// @notice Get the current router address
    /// @return The address of the Reflex router
    function getRouter() external view returns (address) {
        return router;
    }

    /// @notice Get the current reflex admin address
    /// @return The address of the reflex admin
    function getReflexAdmin() external view returns (address) {
        return reflexAdmin;
    }

    function reflexAfterSwap(
        bytes32 triggerPoolId,
        int256 amount0Delta,
        int256 amount1Delta,
        bool zeroForOne,
        address recipient
    ) internal nonReentrant returns (uint256 profit) {
        uint256 swapAmountIn = uint256(amount0Delta > 0 ? amount0Delta : amount1Delta);
        
        // Failsafe: Use try-catch to prevent router failures from breaking the main swap
        try IReflexRouter(router).triggerBackrun(triggerPoolId, uint112(swapAmountIn), zeroForOne, address(this)) 
            returns (uint256 backrunProfit, address profitToken) {
            if (backrunProfit > 0 && profitToken != address(0)) {
                _splitERC20(profitToken, backrunProfit, recipient);
                return backrunProfit;
            }
        } catch {
            // Router call failed, but don't revert the main transaction
            // This ensures the main swap can still complete successfully
        }
        
        return 0;
    }
}
