// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title AddressEntropyEvents
 * @notice Centralized event definitions for the Address Entropy system
 * @dev Contains all events emitted by address-based entropy generation components
 * @author ATrnd
 */
library AddressEntropyEvents {

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new entropy value is generated
    /// @param requester Address that requested entropy
    /// @param segmentIndex The segment index used
    /// @param blockNumber The block number used
    event EntropyGenerated(
        address indexed requester,
        uint256 segmentIndex,
        uint256 blockNumber
    );

    /// @notice Emitted when an address in the entropy array is updated
    /// @param position The position in the array that was updated
    /// @param oldAddress The address that was replaced
    /// @param newAddress The new address
    event EntropyAddressUpdated(
        uint256 indexed position,
        address oldAddress,
        address newAddress
    );

    /// @notice Emitted when a safety fallback is used
    /// @param component_hash Hashed component name for filtering
    /// @param function_hash Hashed function name for filtering
    /// @param error_code Numeric code identifying the specific error
    /// @param component Full component name (not indexed)
    /// @param function_name Full function name (not indexed)
    event SafetyFallbackTriggered(
        bytes32 indexed component_hash,
        bytes32 indexed function_hash,
        uint8 indexed error_code,
        string component,
        string function_name
    );
}
