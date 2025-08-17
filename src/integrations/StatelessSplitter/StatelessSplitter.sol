// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IStatelessSplitter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title StatelessSplitter
/// @notice Abstract contract for stateless ETH/ERC20 splitting without storing funds.
///         Enforces recipient shares via configurable basis points.
abstract contract StatelessSplitter is IStatelessSplitter {
    // ========== Errors ==========

    // ========== Events ==========

    /// @notice Emitted when shares are updated by the admin
    event SharesUpdated(address[] recipients, uint256[] sharesBps);

    /// @notice Emitted after a successful split operation (ETH or ERC20)
    event SplitExecuted(
        address indexed token,
        uint256 totalAmount,
        address[] recipients,
        uint256[] amounts
    );

    // ========== Constants ==========

    /// @notice Total basis points used to express 100% (1% = 100 bps)
    uint256 public constant TOTAL_BPS = 10_000;

    // ========== Storage ==========

    /// @notice Current list of recipient addresses
    address[] public recipients;

    /// @notice Mapping of recipient address to share in basis points
    mapping(address => uint256) public sharesBps;

    // ========== Access Control Hook ==========

    /// @notice Internal function that must be implemented by child contract to enforce admin access control
    function _onlyAdmin() internal view virtual;

    // ========== Public Methods ==========

    /// @inheritdoc IStatelessSplitter
    function updateShares(
        address[] calldata _recipients,
        uint256[] calldata _sharesBps
    ) external override {
        _onlyAdmin();
        _setShares(_recipients, _sharesBps);
        emit SharesUpdated(_recipients, _sharesBps);
    }

    /// @inheritdoc IStatelessSplitter
    function getRecipients()
        external
        view
        override
        returns (address[] memory, uint256[] memory)
    {
        uint256[] memory out = new uint256[](recipients.length);
        for (uint256 i = 0; i < recipients.length; i++) {
            out[i] = sharesBps[recipients[i]];
        }
        return (recipients, out);
    }

    /// @inheritdoc IStatelessSplitter
    function splitERC20(address token, uint256 amount) external override {
        uint256[] memory amounts = new uint256[](recipients.length);

        for (uint256 i = 0; i < recipients.length; i++) {
            address r = recipients[i];
            uint256 share = (amount * sharesBps[r]) / TOTAL_BPS;
            amounts[i] = share;
            require(
                IERC20(token).transferFrom(msg.sender, r, share),
                "ERC20 transfer failed"
            );
        }

        emit SplitExecuted(token, amount, recipients, amounts);
    }

    /// @inheritdoc IStatelessSplitter
    function splitETH() external payable override {
        uint256 value = msg.value;
        uint256[] memory amounts = new uint256[](recipients.length);

        for (uint256 i = 0; i < recipients.length; i++) {
            address r = recipients[i];
            uint256 share = (value * sharesBps[r]) / TOTAL_BPS;
            amounts[i] = share;
            (bool success, ) = r.call{value: share}("");
            require(success, "ETH transfer failed");
        }

        emit SplitExecuted(address(0), value, recipients, amounts);
    }

    // ========== Internal Methods ==========

    /// @notice Internal function to update the share map and recipient list
    function _setShares(
        address[] memory _recipients,
        uint256[] memory _sharesBps
    ) internal {
        require(
            _recipients.length == _sharesBps.length,
            "Recipients and shares length mismatch"
        );

        uint256 total;
        for (uint256 i = 0; i < recipients.length; i++) {
            sharesBps[recipients[i]] = 0;
        }

        for (uint256 i = 0; i < _recipients.length; i++) {
            address r = _recipients[i];
            uint256 s = _sharesBps[i];
            require(r != address(0) && s > 0, "Invalid recipient or share");
            sharesBps[r] = s;
            total += s;
        }

        require(total == TOTAL_BPS, "Invalid total shares");
        recipients = _recipients;
    }
}
