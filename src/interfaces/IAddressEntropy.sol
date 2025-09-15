// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IAddressEntropy
 * @notice Interface for address-based entropy generation with segmented extraction
 * @dev Defines the contract for generating entropy from Ethereum addresses using segment-based extraction
 * @author ATrnd
 */
interface IAddressEntropy {

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when an invalid array size is provided
    error AddressEntropy__InvalidArraySize();

    /// @notice Thrown when segment index is out of bounds
    error AddressEntropy__InvalidSegmentIndex();

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

    /*//////////////////////////////////////////////////////////////
                        ENTROPY GENERATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Generates entropy based on address data with segmented extraction
    /// @dev Updates segment indices, includes transaction counter for additional entropy
    /// @param salt Additional entropy source for randomness
    /// @return Entropy derived from the current address segment
    function getEntropy(uint256 salt) external returns (bytes32);

    /*//////////////////////////////////////////////////////////////
                           STATE QUERIES
    //////////////////////////////////////////////////////////////*/

    // NOTE: Sensitive state inspection functions have been moved to test-only proxy
    // for security reasons. These functions enabled entropy prediction attacks:
    // - getAllEntropyAddresses() -> AddressDataEntropyTestProxy.getAllEntropyAddresses()
    // - getCurrentIndices() -> AddressDataEntropyTestProxy.getCurrentIndices()
    // - getTransactionCounter() -> AddressDataEntropyTestProxy.getTransactionCounter()
    // - extractAllSegments(address addr) -> AddressDataEntropyTestProxy.extractAllSegments()
    // - getAddressSegments(address addr) -> AddressDataEntropyTestProxy.getAddressSegments()

    /*//////////////////////////////////////////////////////////////
                        FALLBACK MONITORING
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the count for a specific error in a specific component
    /// @param componentId The component to check
    /// @param errorCode The error code to check
    /// @return The count of this specific error in this component
    function getComponentErrorCount(uint8 componentId, uint8 errorCode) external view returns (uint256);

    /// @notice Gets the total errors for a specific component
    /// @param componentId The component to check
    /// @return Total error count for the component
    function getComponentTotalErrorCount(uint8 componentId) external view returns (uint256);

    /// @notice Checks if a component has experienced any errors
    /// @param componentId The component to check
    /// @return Whether the component has experienced any errors
    function hasComponentErrors(uint8 componentId) external view returns (bool);

    /// @notice Gets the count of zero address errors in the address extraction component
    /// @return The error count
    function getAddressExtractionZeroAddressCount() external view returns (uint256);

    /// @notice Gets the count of zero segment errors in the segment extraction component
    /// @return The error count
    function getSegmentExtractionZeroSegmentCount() external view returns (uint256);

    /// @notice Gets the count of out of bounds errors in the segment extraction component
    /// @return The error count
    function getSegmentExtractionOutOfBoundsCount() external view returns (uint256);

    /// @notice Gets the count of cycle disruption errors in the entropy generation component
    /// @return The error count
    function getEntropyGenerationCycleDisruptionCount() external view returns (uint256);

    /// @notice Gets the count of zero address errors in the entropy generation component
    /// @return The error count
    function getEntropyGenerationZeroAddressCount() external view returns (uint256);

    /// @notice Gets the count of zero segment errors in entropy generation
    /// @return The error count
    function getEntropyGenerationZeroSegmentCount() external view returns (uint256);
}
