// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AddressDataEntropy} from "../../src/implementations/AddressDataEntropy.sol";
import {AddressSegmentLibrary} from "../../src/libraries/AddressSegmentLibrary.sol";

/**
 * @title AddressDataEntropyTestProxy
 * @notice Minimal proxy for fallback testing - inherits from production contract
 * @dev Adds testing controls to force specific error conditions for comprehensive fallback testing
 * @author ATrnd
 */
contract AddressDataEntropyTestProxy is AddressDataEntropy {
    
    /*//////////////////////////////////////////////////////////////
                             CONTROL FLAGS
    //////////////////////////////////////////////////////////////*/

    /// @notice Control flags to force specific error conditions
    bool private forceZeroAddress;
    bool private forceZeroSegment;
    bool private forceInvalidSegmentIndex;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _initialOwner,
        address[3] memory _seedAddresses
    ) AddressDataEntropy(_initialOwner, _seedAddresses) {
        // Initialize control flags to false
        forceZeroAddress = false;
        forceZeroSegment = false;
        forceInvalidSegmentIndex = false;
    }

    /*//////////////////////////////////////////////////////////////
                         TESTING CONTROL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Reset all control flags to false
    function resetState() external {
        forceZeroAddress = false;
        forceZeroSegment = false;
        forceInvalidSegmentIndex = false;
    }

    /// @notice Force zero address behavior for testing
    /// @param force Whether to force zero address conditions
    function forceSetZeroAddress(bool force) external {
        forceZeroAddress = force;
    }

    /// @notice Force zero segment behavior for testing
    /// @param force Whether to force zero segment conditions
    function forceSetZeroSegment(bool force) external {
        forceZeroSegment = force;
    }

    /// @notice Force invalid segment index behavior for testing
    /// @param force Whether to force invalid segment index conditions
    function forceSetInvalidSegmentIndex(bool force) external {
        forceInvalidSegmentIndex = force;
    }

    /// @notice Force set address index to specific value for testing
    /// @param index The address index to set
    function forceSetAddressIndex(uint256 index) external {
        s_currentAddressIndex = index;
    }

    /// @notice Force set segment index to specific value for testing
    /// @param index The segment index to set
    function forceSetSegmentIndex(uint256 index) external {
        s_currentSegmentIndex = index;
    }

    /// @notice Force set transaction counter to specific value for testing
    /// @param counter The transaction counter value to set
    function forceSetTransactionCounter(uint256 counter) external {
        s_transactionCounter = counter;
    }

    /// @notice Force set update position to specific value for testing
    /// @param position The update position to set
    function forceSetUpdatePosition(uint256 position) external {
        s_nextUpdatePosition = position;
    }

    /// @notice Reset specific fallback counters for isolated testing
    /// @param componentId The component ID to reset
    /// @param errorCode The error code to reset
    function resetFallbackCounter(uint8 componentId, uint8 errorCode) external {
        s_componentErrorCounts[componentId][errorCode] = 0;
    }

    /// @notice Reset all fallback counters for clean testing
    function resetAllFallbackCounters() external {
        for (uint8 componentId = 1; componentId <= 3; componentId++) {
            for (uint8 errorCode = 1; errorCode <= 6; errorCode++) {
                s_componentErrorCounts[componentId][errorCode] = 0;
            }
        }
    }

    /// @notice Force emit a custom fallback event for testing
    /// @param componentId The component ID
    /// @param functionName The function name
    /// @param errorCode The error code
    function forceEmitCustomFallback(
        uint8 componentId,
        string memory functionName,
        uint8 errorCode
    ) external {
        _handleFallback(componentId, functionName, errorCode);
    }

    /// @notice Force increment a component error count for testing
    /// @param componentId The component ID
    /// @param errorCode The error code
    function forceIncrementComponentErrorCount(uint8 componentId, uint8 errorCode) external {
        _incrementComponentErrorCount(componentId, errorCode);
    }

    /*//////////////////////////////////////////////////////////////
                         OVERRIDDEN METHODS FOR TESTING
    //////////////////////////////////////////////////////////////*/

    /// @notice Override extractAddressSegment to allow forcing errors
    /// @param addr The address to extract from
    /// @param segmentIndex The segment index
    /// @return The extracted or fallback segment
    function _extractAddressSegment(address addr, uint256 segmentIndex) 
        internal 
        override 
        returns (bytes5) 
    {
        // Force zero address behavior if enabled
        if (forceZeroAddress) {
            _handleFallback(
                1, // COMPONENT_ADDRESS_EXTRACTION
                "extractAddressSegment",
                1  // ERROR_ZERO_ADDRESS
            );
            return bytes5(keccak256(abi.encode(block.timestamp, segmentIndex, addr)));
        }

        // Force invalid segment index if enabled
        if (forceInvalidSegmentIndex) {
            _handleFallback(
                2, // COMPONENT_SEGMENT_EXTRACTION  
                "extractAddressSegment",
                4  // ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS
            );
            return bytes5(keccak256(abi.encode(block.timestamp, segmentIndex, addr)));
        }

        // Call parent implementation
        bytes5 result = super._extractAddressSegment(addr, segmentIndex);

        // Force zero segment behavior if enabled
        if (forceZeroSegment) {
            _handleFallback(
                2, // COMPONENT_SEGMENT_EXTRACTION
                "extractAddressSegment", 
                3  // ERROR_ZERO_SEGMENT
            );
            return bytes5(keccak256(abi.encode(block.timestamp, segmentIndex, addr)));
        }

        return result;
    }

    /*//////////////////////////////////////////////////////////////
                         OVERRIDE METHODS FOR TESTING  
    //////////////////////////////////////////////////////////////*/

    /// @notice Force inject zero address into entropy addresses array at current index
    /// This simulates the zero address condition that getEntropy checks for
    function injectZeroAddressAtCurrentIndex() external {
        // Simple direct assignment - set the current entropy address to zero
        s_entropyAddresses[s_currentAddressIndex] = address(0);
    }

    /*//////////////////////////////////////////////////////////////
                    TEST-ONLY STATE INSPECTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice TEST ONLY - Get current cycling indices 
    /// @dev NEVER expose in production - enables entropy prediction attacks
    /// @return addressIndex Current address index in entropy array (0-2)
    /// @return segmentIndex Current segment index being extracted (0-3) 
    /// @return updatePosition Next position for address updates (0-2)
    function getCurrentIndices() external view returns (
        uint256 addressIndex, 
        uint256 segmentIndex, 
        uint256 updatePosition
    ) {
        return (s_currentAddressIndex, s_currentSegmentIndex, s_nextUpdatePosition);
    }
    
    /// @notice TEST ONLY - Get entropy addresses array
    /// @dev NEVER expose in production - enables address pool analysis attacks
    /// @return Array of addresses used for entropy generation
    function getAllEntropyAddresses() external view returns (address[3] memory) {
        return s_entropyAddresses;
    }
    
    /// @notice TEST ONLY - Get transaction counter
    /// @dev NEVER expose in production - enables timing prediction attacks
    /// @return Total number of entropy requests processed
    function getTransactionCounter() external view returns (uint256) {
        return s_transactionCounter;
    }

    /// @notice TEST ONLY - Extract all segments of an address for analysis
    /// @dev NEVER expose in production - enables segment pattern analysis attacks
    /// @param addr The address to extract segments from
    /// @return An array of all segments from the address
    function extractAllSegments(address addr) external view returns (bytes5[4] memory) {
        bytes5[4] memory segments;

        for (uint256 i = 0; i < 4; i++) {
            // For view function, we need to use a simplified version without state changes
            if (addr == address(0)) {
                segments[i] = AddressSegmentLibrary.generateFallbackSegment(i);
                continue;
            }

            // Extract segment using shift
            segments[i] = bytes5(AddressSegmentLibrary.extractSegmentWithShift(addr, i));
        }

        return segments;
    }

    /// @notice TEST ONLY - Extract all segments of an address for debugging purposes
    /// @dev NEVER expose in production - wrapper function for extractAllSegments
    /// @param addr The address to extract segments from
    /// @return An array of all segments from the address
    function getAddressSegments(address addr) external view returns (bytes5[4] memory) {
        return this.extractAllSegments(addr);
    }

    /*//////////////////////////////////////////////////////////////
                         EXPOSED HELPER METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Exposed version of getComponentName for testing
    /// @param componentId The component ID
    /// @return The component name
    function exposedGetComponentName(uint8 componentId) external pure returns (string memory) {
        return _getComponentName(componentId);
    }

    /// @notice Public wrapper to call extractAddressSegment for direct testing
    /// @param addr The address to extract from  
    /// @param segmentIndex The segment index
    /// @return The extracted segment
    function callExtractAddressSegment(address addr, uint256 segmentIndex) 
        external 
        returns (bytes5) 
    {
        return _extractAddressSegment(addr, segmentIndex);
    }

    /// @notice Exposed updateEntropyState for testing state update mechanisms
    function exposedUpdateEntropyState() external {
        _updateEntropyState();
    }

    /// @notice Exposed tryUpdateAddress for testing address updating logic
    /// @param newAddress The address to try updating
    /// @return Whether the address was updated
    function exposedTryUpdateAddress(address newAddress) external returns (bool) {
        return _tryUpdateAddress(newAddress);
    }

    /// @notice Exposed generateEmergencyEntropy for testing emergency entropy patterns
    /// @param salt The entropy salt
    /// @param currentTx The current transaction data
    /// @return The generated emergency entropy
    function exposedGenerateEmergencyEntropy(uint256 salt, uint256 currentTx) external view returns (bytes32) {
        return _generateEmergencyEntropy(salt, currentTx);
    }

    /// @notice Generate fallback segments for all indices for testing
    /// @param segmentIndex The segment index
    /// @return The fallback segment
    function exposedGenerateFallbackSegment(uint256 segmentIndex) external view returns (bytes5) {
        return AddressSegmentLibrary.generateFallbackSegment(segmentIndex);
    }

    /// @notice Test all segments extraction at once
    /// @param addr The address to extract from
    /// @return All extracted segments
    function exposedExtractAllSegments(address addr) external view returns (bytes5[4] memory) {
        bytes5[4] memory segments;
        for (uint256 i = 0; i < 4; i++) {
            // Use the view-only version without state changes
            if (addr == address(0)) {
                segments[i] = AddressSegmentLibrary.generateFallbackSegment(i);
            } else {
                uint40 extracted = AddressSegmentLibrary.extractSegmentWithShift(addr, i);
                if (extracted == 0) {
                    segments[i] = AddressSegmentLibrary.generateFallbackSegment(i);
                } else {
                    segments[i] = bytes5(extracted);
                }
            }
        }
        return segments;
    }
}
