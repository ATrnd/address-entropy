// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title AddressEntropyConstants
 * @notice Centralized constants for the Address Entropy system
 * @dev Contains all constants used across address-based entropy generation components
 * @author ATrnd
 */
library AddressEntropyConstants {

    /*//////////////////////////////////////////////////////////////
                            ARRAY & SEGMENT CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum address pool size for entropy generation
    /// @dev Optimized balance: 3 addresses × 4 segments = 12 unique entropy sources, minimizes storage costs
    uint256 internal constant ADDRESS_ARRAY_SIZE = 3;

    /// @notice Address segmentation count for 160→40bit extraction
    /// @dev 160-bit address ÷ 4 segments = 40 bits each, maximizes entropy density per address
    uint256 internal constant SEGMENTS_PER_ADDRESS = 4;

    /// @notice Index cycling increment for deterministic state progression
    /// @dev Single-step advancement
    uint256 internal constant INDEX_INCREMENT = 1;

    /*//////////////////////////////////////////////////////////////
                            ZERO VALUE CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Zero address constant for validation and initialization
    /// @dev Used throughout protocol for zero checks
    address internal constant ZERO_ADDRESS = address(0);

    /// @notice Zero uint constant for validation and initialization
    /// @dev Standard zero value for counter resets and bounds checking
    uint256 internal constant ZERO_UINT = 0;

    /// @notice Zero segment constant
    uint40 internal constant ZERO_SEGMENT = 0;

    /// @notice No error code constant
    uint8 internal constant ERROR_CODE_NONE = 0;

    /*//////////////////////////////////////////////////////////////
                            BITMASK & SHIFT CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Bitmask for 40-bit segment isolation after right-shift
    /// @dev 0xFFFFFFFFFF masks lower 40 bits
    uint160 internal constant SEGMENT_BITMASK = 0xFFFFFFFFFF;

    /// @notice Bit shift positions for 160→40bit address segmentation
    /// @dev Shifts enable extraction: bits 0-39, 40-79, 80-119, 120-159 from address
    uint8 internal constant SEGMENT_SHIFT_0 = 0;
    uint8 internal constant SEGMENT_SHIFT_1 = 40;
    uint8 internal constant SEGMENT_SHIFT_2 = 80;
    uint8 internal constant SEGMENT_SHIFT_3 = 120;

    /*//////////////////////////////////////////////////////////////
                            SEGMENT INDEX CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Segment index constants
    uint8 internal constant SEGMENT_INDEX_0 = 0;
    uint8 internal constant SEGMENT_INDEX_1 = 1;
    uint8 internal constant SEGMENT_INDEX_2 = 2;
    uint8 internal constant SEGMENT_INDEX_3 = 3;

    /*//////////////////////////////////////////////////////////////
                            COMPONENT IDENTIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Component identifiers for fallback tracking
    uint8 internal constant COMPONENT_ADDRESS_EXTRACTION = 1;
    uint8 internal constant COMPONENT_SEGMENT_EXTRACTION = 2;
    uint8 internal constant COMPONENT_ENTROPY_GENERATION = 3;

    /*//////////////////////////////////////////////////////////////
                            ERROR CODES
    //////////////////////////////////////////////////////////////*/

    /// @notice Error codes for safety fallbacks
    uint8 internal constant ERROR_ZERO_ADDRESS = 1;
    uint8 internal constant ERROR_INSUFFICIENT_ADDRESS_DIVERSITY = 2;
    uint8 internal constant ERROR_ZERO_SEGMENT = 3;
    uint8 internal constant ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS = 4;
    uint8 internal constant ERROR_UPDATE_CYCLE_DISRUPTION = 5;
    uint8 internal constant ERROR_ENTROPY_ZERO_SEGMENT = 6;

    /*//////////////////////////////////////////////////////////////
                            FUNCTION NAME CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Function name constants
    string internal constant FUNC_EXTRACT_ADDRESS_SEGMENT = "extractAddressSegment";
    string internal constant FUNC_GET_ENTROPY = "getEntropy";
    string internal constant FUNC_UPDATE_ENTROPY_STATE = "updateEntropyState";

    /*//////////////////////////////////////////////////////////////
                            COMPONENT NAME CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Component name constants
    string internal constant COMPONENT_NAME_ADDRESS_EXTRACTION = "AddressExtraction";
    string internal constant COMPONENT_NAME_SEGMENT_EXTRACTION = "SegmentExtraction";
    string internal constant COMPONENT_NAME_ENTROPY_GENERATION = "EntropyGeneration";
    string internal constant COMPONENT_NAME_UNKNOWN = "Unknown";
}
