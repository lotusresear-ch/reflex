// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "../interfaces/IReflexRouter.sol";
import "./StatelessSplitter/StatelessSplitter.sol";

abstract contract ReflexAfterSwap is StatelessSplitter {
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

    function _afterSwap(
        bytes32 triggerPoolId,
        int256 amount0Delta,
        int256 amount1Delta,
        bool zeroForOne,
        address recipient
    ) internal nonReentrant returns (uint256 profit) {
        uint256 swapAmountIn = uint256(amount0Delta > 0 ? amount0Delta : amount1Delta);
        (uint256 backrunProfit,) =
            IReflexRouter(router).triggerBackrun(triggerPoolId, uint112(swapAmountIn), zeroForOne, recipient);
        return backrunProfit;
    }
}
