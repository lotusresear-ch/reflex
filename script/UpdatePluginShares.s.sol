// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {AlgebraBasePluginV3} from "../src/integrations/algebra/full/AlgebraBasePluginV3.sol";

/**
 * @title UpdatePluginShares
 * @notice Script to update profit sharing configuration on AlgebraBasePluginV3 contract
 * @dev Run with: forge script script/UpdatePluginShares.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
 *
 * Environment Variables Required:
 * - PLUGIN_ADDRESS: Address of the deployed AlgebraBasePluginV3 contract
 * - RECIPIENTS: Comma-separated list of recipient addresses (e.g., "0x123...,0x456...")
 * - SHARES: Comma-separated list of share amounts in basis points (e.g., "5000,3000,2000")
 *
 * Optional Environment Variables:
 * - DRY_RUN: Set to "true" to simulate without broadcasting
 * - VERIFY_BEFORE_UPDATE: Set to "true" to verify current state before updating
 *
 * @dev Total shares must equal 10000 (100%)
 * @dev Only the reflex admin can update shares
 */
contract UpdatePluginShares is Script {
    // Contract reference
    AlgebraBasePluginV3 public plugin;

    // Update parameters
    address public pluginAddress;
    address[] public recipients;
    uint256[] public sharesBps;

    // Configuration
    bool public isDryRun;
    bool public verifyBeforeUpdate;

    // Events
    event SharesUpdatePrepared(address indexed plugin, address[] recipients, uint256[] sharesBps, uint256 totalShares);

    event SharesUpdated(address indexed plugin, address[] recipients, uint256[] sharesBps);

    function setUp() public {
        // Load plugin address
        pluginAddress = vm.envAddress("PLUGIN_ADDRESS");
        plugin = AlgebraBasePluginV3(pluginAddress);

        // Parse recipients and shares from environment variables
        _parseRecipientsAndShares();

        // Load optional configuration
        _loadConfiguration();

        // Validate parameters
        _validateParameters();
    }

    function run() public {
        console.log("=== Update Plugin Shares ===");
        console.log("Chain ID:", block.chainid);
        console.log("Sender:", msg.sender);
        console.log("Plugin Address:", pluginAddress);
        console.log("");

        // Verify current state if requested
        if (verifyBeforeUpdate) {
            _verifyCurrentState();
        }

        // Log update parameters
        _logUpdateParameters();

        if (isDryRun) {
            console.log("DRY RUN MODE - No transactions will be broadcast");
            _simulateUpdate();
        } else {
            _executeUpdate();
        }

        console.log("=== Update Complete ===");
    }

    function _parseRecipientsAndShares() internal {
        // Parse recipients
        string memory recipientsStr = vm.envString("RECIPIENTS");
        string[] memory recipientStrings = _splitString(recipientsStr, ",");

        recipients = new address[](recipientStrings.length);
        for (uint256 i = 0; i < recipientStrings.length; i++) {
            recipients[i] = vm.parseAddress(_trim(recipientStrings[i]));
        }

        // Parse shares
        string memory sharesStr = vm.envString("SHARES");
        string[] memory shareStrings = _splitString(sharesStr, ",");

        sharesBps = new uint256[](shareStrings.length);
        for (uint256 i = 0; i < shareStrings.length; i++) {
            sharesBps[i] = vm.parseUint(_trim(shareStrings[i]));
        }
    }

    function _loadConfiguration() internal {
        // Check for dry run mode
        try vm.envBool("DRY_RUN") returns (bool dryRun) {
            isDryRun = dryRun;
        } catch {
            isDryRun = false;
        }

        // Check for verification flag
        try vm.envBool("VERIFY_BEFORE_UPDATE") returns (bool verify) {
            verifyBeforeUpdate = verify;
        } catch {
            verifyBeforeUpdate = true; // Default to verification
        }
    }

    function _validateParameters() internal view {
        require(pluginAddress != address(0), "PLUGIN_ADDRESS cannot be zero");
        require(recipients.length > 0, "At least one recipient required");
        require(recipients.length == sharesBps.length, "Recipients and shares length mismatch");
        require(recipients.length <= 10, "Too many recipients (max 10)");

        // Validate total shares equal 10000 (100%)
        uint256 totalShares = 0;
        for (uint256 i = 0; i < sharesBps.length; i++) {
            require(recipients[i] != address(0), "Recipient cannot be zero address");
            require(sharesBps[i] > 0, "Share must be greater than 0");
            totalShares += sharesBps[i];
        }
        require(totalShares == 10000, "Total shares must equal 10000 (100%)");

        // Check for duplicate recipients
        for (uint256 i = 0; i < recipients.length; i++) {
            for (uint256 j = i + 1; j < recipients.length; j++) {
                require(recipients[i] != recipients[j], "Duplicate recipient detected");
            }
        }

        console.log("All parameters validated successfully");
    }

    function _verifyCurrentState() internal view {
        console.log("Current Plugin State:");
        console.log("- Plugin Address:", address(plugin));
        console.log("- Reflex Enabled:", plugin.reflexEnabled());
        console.log("- Router Address:", plugin.getRouter());
        console.log("- Reflex Admin:", plugin.getReflexAdmin());

        // Get current recipients and shares
        (address[] memory currentRecipients, uint256[] memory currentShares) = plugin.getRecipients();
        console.log("- Current Recipients Count:", currentRecipients.length);

        for (uint256 i = 0; i < currentRecipients.length; i++) {
            console.log("  - Recipient:", currentRecipients[i]);
            console.log("    Share:", currentShares[i], "bps");
        }
        console.log("");
    }

    function _logUpdateParameters() internal view {
        console.log("Update Parameters:");
        console.log("- Recipients Count:", recipients.length);

        uint256 totalShares = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            console.log("  - Recipient:", recipients[i]);
            console.log("    Share:", sharesBps[i], "bps");
            totalShares += sharesBps[i];
        }
        console.log("- Total Shares:", totalShares, "bps (100.00%)");
        console.log("");
    }

    function _simulateUpdate() internal {
        console.log("Simulating updateShares call...");

        // Emit event for tracking
        emit SharesUpdatePrepared(address(plugin), recipients, sharesBps, _getTotalShares());

        try plugin.updateShares(recipients, sharesBps) {
            console.log("[ OK ] Simulation successful - updateShares would succeed");
        } catch Error(string memory reason) {
            console.log("[ FAIL ] Simulation failed:", reason);
            revert("Simulation failed");
        } catch {
            console.log("[ FAIL ] Simulation failed with unknown error");
            revert("Simulation failed with unknown error");
        }
    }

    function _executeUpdate() internal {
        console.log("Executing updateShares transaction...");

        vm.startBroadcast();

        try plugin.updateShares(recipients, sharesBps) {
            console.log("[ OK ] Shares updated successfully");

            // Emit event
            emit SharesUpdated(address(plugin), recipients, sharesBps);
        } catch Error(string memory reason) {
            console.log("[ FAIL ] Update failed:", reason);
            revert("Update failed");
        } catch {
            console.log("[ FAIL ] Update failed with unknown error");
            revert("Update failed with unknown error");
        }

        vm.stopBroadcast();

        // Verify the update
        _verifyUpdate();
    }

    function _verifyUpdate() internal view {
        console.log("Verifying update...");

        (address[] memory newRecipients, uint256[] memory newShares) = plugin.getRecipients();
        require(newRecipients.length == recipients.length, "Recipient count mismatch");

        uint256 totalShares = 0;

        for (uint256 i = 0; i < newRecipients.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < recipients.length; j++) {
                if (newRecipients[i] == recipients[j]) {
                    require(newShares[i] == sharesBps[j], "Share mismatch");
                    found = true;
                    break;
                }
            }
            require(found, "Unexpected recipient");
            totalShares += newShares[i];
        }

        require(totalShares == 10000, "Total shares verification failed");
        console.log("[ OK ] Update verified successfully");
    }

    function _getTotalShares() internal view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < sharesBps.length; i++) {
            total += sharesBps[i];
        }
        return total;
    }

    // Helper function to split string by delimiter
    function _splitString(string memory str, string memory delimiter) internal pure returns (string[] memory) {
        bytes memory strBytes = bytes(str);
        bytes memory delimiterBytes = bytes(delimiter);

        if (strBytes.length == 0) {
            return new string[](0);
        }

        // Count occurrences of delimiter
        uint256 count = 1;
        for (uint256 i = 0; i <= strBytes.length - delimiterBytes.length; i++) {
            bool isMatch = true;
            for (uint256 j = 0; j < delimiterBytes.length; j++) {
                if (strBytes[i + j] != delimiterBytes[j]) {
                    isMatch = false;
                    break;
                }
            }
            if (isMatch) {
                count++;
                i += delimiterBytes.length - 1;
            }
        }

        // Split the string
        string[] memory result = new string[](count);
        uint256 resultIndex = 0;
        uint256 startIndex = 0;

        for (uint256 i = 0; i <= strBytes.length - delimiterBytes.length; i++) {
            bool isMatch = true;
            for (uint256 j = 0; j < delimiterBytes.length; j++) {
                if (strBytes[i + j] != delimiterBytes[j]) {
                    isMatch = false;
                    break;
                }
            }
            if (isMatch) {
                result[resultIndex] = _substring(str, startIndex, i);
                resultIndex++;
                startIndex = i + delimiterBytes.length;
                i += delimiterBytes.length - 1;
            }
        }

        // Add the last part
        result[resultIndex] = _substring(str, startIndex, strBytes.length);

        return result;
    }

    // Helper function to extract substring
    function _substring(string memory str, uint256 start, uint256 end) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = strBytes[i];
        }
        return string(result);
    }

    // Helper function to trim whitespace
    function _trim(string memory str) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        if (strBytes.length == 0) return str;

        uint256 start = 0;
        uint256 end = strBytes.length;

        // Trim leading whitespace
        while (
            start < end
                && (
                    strBytes[start] == 0x20 || strBytes[start] == 0x09 || strBytes[start] == 0x0A || strBytes[start] == 0x0D
                )
        ) {
            start++;
        }

        // Trim trailing whitespace
        while (
            end > start
                && (
                    strBytes[end - 1] == 0x20 || strBytes[end - 1] == 0x09 || strBytes[end - 1] == 0x0A
                        || strBytes[end - 1] == 0x0D
                )
        ) {
            end--;
        }

        return _substring(str, start, end);
    }

    // Helper functions for testing and verification
    function getUpdateParameters() external view returns (address[] memory, uint256[] memory) {
        return (recipients, sharesBps);
    }

    function validateUpdateParameters() external view returns (bool) {
        if (recipients.length == 0 || recipients.length != sharesBps.length) return false;

        uint256 totalShares = 0;
        for (uint256 i = 0; i < sharesBps.length; i++) {
            if (recipients[i] == address(0) || sharesBps[i] == 0) return false;
            totalShares += sharesBps[i];
        }

        return totalShares == 10000;
    }
}
