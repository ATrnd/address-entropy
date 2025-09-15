// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAddressFallbackHandler} from "../interfaces/IAddressFallbackHandler.sol";
import {AddressEntropyConstants} from "../constants/AddressEntropyConstants.sol";
import {AddressEntropyEvents} from "../constants/AddressEntropyEvents.sol";
import {AddressFallbackLibrary} from "../libraries/AddressFallbackLibrary.sol";

/**
 * @title AbstractAddressFallbackHandler
 * @notice Abstract base implementation for fallback handling in address entropy systems
 * @dev Provides common functionality for error tracking, fallback coordination, and emergency entropy
 * @author ATrnd
 */
abstract contract AbstractAddressFallbackHandler is IAddressFallbackHandler {

    /*//////////////////////////////////////////////////////////////
                            USING STATEMENTS
    //////////////////////////////////////////////////////////////*/

    using AddressFallbackLibrary for uint8;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Component-specific fallback tracking
    /// @dev Maps component ID => error code => count
    mapping(uint8 => mapping(uint8 => uint256)) internal s_componentErrorCounts;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Import event from centralized event library
    /// @dev Re-declare the event locally for emission
    event SafetyFallbackTriggered(
        bytes32 indexed component_hash,
        bytes32 indexed function_hash,
        uint8 indexed error_code,
        string component,
        string function_name
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Errors are inherited from IAddressFallbackHandler interface

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the count for a specific error in a specific component
    /// @param componentId The component to check
    /// @param errorCode The error code to check
    /// @return The count of this specific error in this component
    function getComponentErrorCount(uint8 componentId, uint8 errorCode) external view virtual override returns (uint256) {
        return s_componentErrorCounts[componentId][errorCode];
    }

    /// @notice Gets the total errors for a specific component
    /// @param componentId The component to check
    /// @return Total error count for the component
    function getComponentTotalErrorCount(uint8 componentId) external view virtual override returns (uint256) {
        return _calculateComponentTotalErrorCount(componentId);
    }

    /// @notice Checks if a component has experienced any errors
    /// @param componentId The component to check
    /// @return Whether the component has experienced any errors
    function hasComponentErrors(uint8 componentId) external view virtual override returns (bool) {
        return _checkComponentHasErrors(componentId);
    }

    /// @notice Gets the count of zero address errors in the address extraction component
    /// @return The error count
    function getAddressExtractionZeroAddressCount() external view virtual override returns (uint256) {
        return s_componentErrorCounts[AddressEntropyConstants.COMPONENT_ADDRESS_EXTRACTION][AddressEntropyConstants.ERROR_ZERO_ADDRESS];
    }

    /// @notice Gets the count of zero segment errors in the segment extraction component
    /// @return The error count
    function getSegmentExtractionZeroSegmentCount() external view virtual override returns (uint256) {
        return s_componentErrorCounts[AddressEntropyConstants.COMPONENT_SEGMENT_EXTRACTION][AddressEntropyConstants.ERROR_ZERO_SEGMENT];
    }

    /// @notice Gets the count of out of bounds errors in the segment extraction component
    /// @return The error count
    function getSegmentExtractionOutOfBoundsCount() external view virtual override returns (uint256) {
        return s_componentErrorCounts[AddressEntropyConstants.COMPONENT_SEGMENT_EXTRACTION][AddressEntropyConstants.ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS];
    }

    /// @notice Gets the count of cycle disruption errors in the entropy generation component
    /// @return The error count
    function getEntropyGenerationCycleDisruptionCount() external view virtual override returns (uint256) {
        return s_componentErrorCounts[AddressEntropyConstants.COMPONENT_ENTROPY_GENERATION][AddressEntropyConstants.ERROR_UPDATE_CYCLE_DISRUPTION];
    }

    /// @notice Gets the count of zero address errors in the entropy generation component
    /// @return The error count
    function getEntropyGenerationZeroAddressCount() external view virtual override returns (uint256) {
        return s_componentErrorCounts[AddressEntropyConstants.COMPONENT_ENTROPY_GENERATION][AddressEntropyConstants.ERROR_ZERO_ADDRESS];
    }

    /// @notice Gets the count of zero segment errors in entropy generation
    /// @return The error count
    function getEntropyGenerationZeroSegmentCount() external view virtual override returns (uint256) {
        return s_componentErrorCounts[AddressEntropyConstants.COMPONENT_ENTROPY_GENERATION][AddressEntropyConstants.ERROR_ENTROPY_ZERO_SEGMENT];
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Handles a fallback event with tracking and event emission
    /// @dev Increments component-specific error counter and emits event
    /// @param componentId The component where the fallback occurred
    /// @param functionName The function where the fallback occurred
    /// @param errorCode The specific error code
    function handleFallback(uint8 componentId, string memory functionName, uint8 errorCode) internal {
        _handleFallbackInternal(componentId, functionName, errorCode);
    }

    /// @notice Increments the error counter for a specific component and error type
    /// @dev Used for tracking specific fallback scenarios
    /// @param componentId The component ID where the error occurred
    /// @param errorCode The specific error code
    /// @return The new error count for this component/error combination
    function incrementComponentErrorCount(uint8 componentId, uint8 errorCode) internal returns (uint256) {
        return _incrementComponentErrorCountInternal(componentId, errorCode);
    }

    /// @notice Internal implementation of fallback handling
    /// @dev Template method that can be extended by concrete implementations
    /// @param componentId The component where the fallback occurred
    /// @param functionName The function where the fallback occurred
    /// @param errorCode The specific error code
    function _handleFallbackInternal(
        uint8 componentId,
        string memory functionName,
        uint8 errorCode
    ) internal virtual {
        // Increment the specific error counter for this component
        _incrementComponentErrorCountInternal(componentId, errorCode);

        // Get component name for the event
        string memory componentName = AddressFallbackLibrary.getComponentName(componentId);

        // Emit the event
        emit SafetyFallbackTriggered(
            keccak256(bytes(componentName)),
            keccak256(bytes(functionName)),
            errorCode,
            componentName,
            functionName
        );
    }

    /// @notice Internal implementation of error counter increment
    /// @dev Updates the component error mapping and returns new count
    /// @param componentId The component ID where the error occurred
    /// @param errorCode The specific error code
    /// @return The new error count for this component/error combination
    function _incrementComponentErrorCountInternal(uint8 componentId, uint8 errorCode) internal virtual returns (uint256) {
        s_componentErrorCounts[componentId][errorCode] = AddressFallbackLibrary.incrementComponentErrorCount(
            s_componentErrorCounts[componentId][errorCode]
        );
        return s_componentErrorCounts[componentId][errorCode];
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Generates emergency entropy when normal entropy generation fails
    /// @dev Falls back to alternative entropy sources
    /// @param salt Additional entropy source provided by caller
    /// @param txCounter The current transaction counter
    /// @return Emergency entropy value
    function generateEmergencyEntropy(uint256 salt, uint256 txCounter) internal view returns (bytes32) {
        return _generateEmergencyEntropyInternal(salt, txCounter);
    }

    /// @notice Internal implementation of emergency entropy generation
    /// @dev Template method that can be extended for different emergency strategies
    /// @param salt Additional entropy source provided by caller
    /// @param txCounter The current transaction counter
    /// @return Emergency entropy value
    function _generateEmergencyEntropyInternal(uint256 salt, uint256 txCounter) internal view virtual returns (bytes32) {
        return AddressFallbackLibrary.generateEmergencyEntropy(
            salt,
            txCounter,
            s_componentErrorCounts[AddressEntropyConstants.COMPONENT_ADDRESS_EXTRACTION][AddressEntropyConstants.ERROR_ZERO_ADDRESS],
            s_componentErrorCounts[AddressEntropyConstants.COMPONENT_SEGMENT_EXTRACTION][AddressEntropyConstants.ERROR_ZERO_SEGMENT]
        );
    }

    /// @notice Calculates total error count for a specific component
    /// @dev Internal helper for component error aggregation
    /// @param componentId The component to check
    /// @return Total error count for the component
    function _calculateComponentTotalErrorCount(uint8 componentId) internal view virtual returns (uint256) {
        uint256 total = AddressEntropyConstants.ZERO_UINT;
        // Direct access to known error codes instead of loops
        total += s_componentErrorCounts[componentId][AddressEntropyConstants.ERROR_ZERO_ADDRESS];
        total += s_componentErrorCounts[componentId][AddressEntropyConstants.ERROR_INSUFFICIENT_ADDRESS_DIVERSITY];
        total += s_componentErrorCounts[componentId][AddressEntropyConstants.ERROR_ZERO_SEGMENT];
        total += s_componentErrorCounts[componentId][AddressEntropyConstants.ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS];
        total += s_componentErrorCounts[componentId][AddressEntropyConstants.ERROR_UPDATE_CYCLE_DISRUPTION];
        total += s_componentErrorCounts[componentId][AddressEntropyConstants.ERROR_ENTROPY_ZERO_SEGMENT];
        return total;
    }

    /// @notice Checks if a component has any errors
    /// @dev Internal helper for component error detection
    /// @param componentId The component to check
    /// @return Whether the component has experienced any errors
    function _checkComponentHasErrors(uint8 componentId) internal view virtual returns (bool) {
        // Direct checks instead of loops
        return s_componentErrorCounts[componentId][AddressEntropyConstants.ERROR_ZERO_ADDRESS] > AddressEntropyConstants.ZERO_UINT ||
               s_componentErrorCounts[componentId][AddressEntropyConstants.ERROR_INSUFFICIENT_ADDRESS_DIVERSITY] > AddressEntropyConstants.ZERO_UINT ||
               s_componentErrorCounts[componentId][AddressEntropyConstants.ERROR_ZERO_SEGMENT] > AddressEntropyConstants.ZERO_UINT ||
               s_componentErrorCounts[componentId][AddressEntropyConstants.ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS] > AddressEntropyConstants.ZERO_UINT ||
               s_componentErrorCounts[componentId][AddressEntropyConstants.ERROR_UPDATE_CYCLE_DISRUPTION] > AddressEntropyConstants.ZERO_UINT ||
               s_componentErrorCounts[componentId][AddressEntropyConstants.ERROR_ENTROPY_ZERO_SEGMENT] > AddressEntropyConstants.ZERO_UINT;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Converts a component ID to its string name
    /// @param componentId The component identifier
    /// @return The string name of the component
    function getComponentName(uint8 componentId) internal pure returns (string memory) {
        return AddressFallbackLibrary.getComponentName(componentId);
    }

}
