// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AddressEntropyConstants } from "../constants/AddressEntropyConstants.sol";

/**
 * @title AddressFallbackLibrary
 * @notice Utility functions for emergency entropy generation and component management
 * @dev Contains fallback logic extracted from AddressDataEntropy
 * @author ATrnd
 */
library AddressFallbackLibrary {
    /*//////////////////////////////////////////////////////////////
                         EMERGENCY ENTROPY GENERATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Generates emergency entropy when normal entropy generation fails
    /// @param salt Additional entropy source provided by caller
    /// @param txCounter The current transaction counter
    /// @param addressExtractionZeroAddressCount Error count for address extraction zero address errors
    /// @param segmentExtractionZeroSegmentCount Error count for segment extraction zero segment errors
    /// @return Emergency entropy value
    function generateEmergencyEntropy(
        uint256 salt,
        uint256 txCounter,
        uint256 addressExtractionZeroAddressCount,
        uint256 segmentExtractionZeroSegmentCount
    )
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                // Block context - different from primary approach
                block.timestamp,
                block.number,
                block.prevrandao,
                block.basefee,
                block.coinbase,
                block.gaslimit,
                block.chainid,
                // Transaction data
                msg.sender,
                salt,
                // Add uniqueness factors
                txCounter,
                address(this),
                // Include most relevant fallback counters directly
                addressExtractionZeroAddressCount,
                segmentExtractionZeroSegmentCount
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                         COMPONENT MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Converts a component ID to its string name
    /// @param componentId The component identifier
    /// @return The string name of the component
    function getComponentName(uint8 componentId) internal pure returns (string memory) {
        if (componentId == AddressEntropyConstants.COMPONENT_ADDRESS_EXTRACTION) {
            return AddressEntropyConstants.COMPONENT_NAME_ADDRESS_EXTRACTION;
        }
        if (componentId == AddressEntropyConstants.COMPONENT_SEGMENT_EXTRACTION) {
            return AddressEntropyConstants.COMPONENT_NAME_SEGMENT_EXTRACTION;
        }
        if (componentId == AddressEntropyConstants.COMPONENT_ENTROPY_GENERATION) {
            return AddressEntropyConstants.COMPONENT_NAME_ENTROPY_GENERATION;
        }
        if (componentId == AddressEntropyConstants.COMPONENT_ACCESS_CONTROL) {
            return AddressEntropyConstants.COMPONENT_NAME_ACCESS_CONTROL;
        }
        return AddressEntropyConstants.COMPONENT_NAME_UNKNOWN;
    }

    /*//////////////////////////////////////////////////////////////
                         ERROR COUNTER MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Increments the error counter for a specific component and error type
    /// @param currentCount The current error count
    /// @return The new error count for this component/error combination
    function incrementComponentErrorCount(uint256 currentCount) internal pure returns (uint256) {
        return currentCount + AddressEntropyConstants.INDEX_INCREMENT;
    }
}
