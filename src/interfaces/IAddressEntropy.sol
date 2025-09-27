// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAddressFallbackHandler} from "./IAddressFallbackHandler.sol";

/**
 * @title IAddressEntropy
 * @notice Interface for address-based entropy generation with segmented extraction
 * @dev Defines entropy generation and fallback monitoring for 160→40bit address segmentation
 * @author ATrnd
 */
interface IAddressEntropy is IAddressFallbackHandler {

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when an invalid array size is provided
    error AddressEntropy__InvalidArraySize();

    /// @notice Thrown when segment index is out of bounds
    error AddressEntropy__InvalidSegmentIndex();

    /// @notice Thrown when trying to call getEntropy before orchestrator is configured
    error AddressEntropy__OrchestratorNotConfigured();

    /// @notice Thrown when unauthorized address attempts to call getEntropy
    error AddressEntropy__UnauthorizedOrchestrator();

    /// @notice Thrown when trying to configure orchestrator more than once
    error AddressEntropy__OrchestratorAlreadyConfigured();

    /// @notice Thrown when trying to set zero address as orchestrator
    error AddressEntropy__InvalidOrchestratorAddress();

    /// @notice Thrown when invalid addresses are provided (consolidated from engine)
    error AddressEntropy__InvalidAddress();

    /// @notice Thrown when caller is not authorized (consolidated from engine)
    error AddressEntropy__Unauthorized();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new entropy value is generated
    /// @param requester Address that requested entropy (orchestrator)
    /// @param actualCaller The actual caller address used for entropy generation
    /// @param segmentIndex The segment index used
    /// @param blockNumber The block number used
    event EntropyGenerated(
        address indexed requester,
        address indexed actualCaller,
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

    /// @notice Emitted when orchestrator is successfully configured
    /// @param orchestrator Address of the configured orchestrator contract
    event OrchestratorConfigured(address indexed orchestrator);

    /// @notice Emitted when a general fallback is triggered (consolidated from engine)
    /// @param reason Human-readable reason for the fallback
    /// @param fallbackEntropy The generated fallback entropy value
    event FallbackTriggered(string reason, bytes32 fallbackEntropy);

    /*//////////////////////////////////////////////////////////////
                        ENTROPY GENERATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Generates entropy from current address data with salt
    /// @dev Triple-cycling state management: advances address index, segment index, and update position
    /// @param salt Additional entropy source for randomness enhancement
    /// @param actualCaller The actual caller address to use for entropy generation (not msg.sender)
    /// @return 32-byte entropy value derived from 40-bit address segment with block and transaction context
    function getEntropy(uint256 salt, address actualCaller) external returns (bytes32);

    /*//////////////////////////////////////////////////////////////
                           ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /// @notice Configures the authorized orchestrator address (one-time only)
    /// @dev Can only be called by contract owner and only once
    /// @param _orchestrator Address of the EntropyMachine orchestrator contract
    function setOrchestratorOnce(address _orchestrator) external;

    /// @notice Gets the configured orchestrator address
    /// @dev Returns zero address if not configured
    /// @return The orchestrator address
    function getOrchestrator() external view returns (address);

    /// @notice Checks if orchestrator has been configured
    /// @dev Returns true if orchestrator is set and valid
    /// @return True if orchestrator is configured
    function isOrchestratorConfigured() external view returns (bool);
}
