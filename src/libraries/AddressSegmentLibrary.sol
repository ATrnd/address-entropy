// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AddressEntropyConstants } from "../constants/AddressEntropyConstants.sol";

/**
 * @title AddressSegmentLibrary
 * @notice Pure utility functions for address segment extraction and manipulation
 * @dev Bit manipulation library for 160→40bit address segmentation
 * @author ATrnd
 */
library AddressSegmentLibrary {
    /// @notice Local constant for array declarations
    uint256 private constant SEGMENTS_PER_ADDRESS = 4;

    /*//////////////////////////////////////////////////////////////
                         SEGMENT EXTRACTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Extracts 40-bit segment from address using conditional bit shifts
    /// @dev Uses right-shift operations with 0xFFFFFFFFFF mask for O(1) extraction
    /// @param addr Ethereum address for 160→40bit segmentation
    /// @param segmentIndex Segment position (0-3, maps to shifts: 0, 40, 80, 120 bits)
    /// @return 40-bit segment as uint40 from specified address position
    function extractSegmentWithShift(address addr, uint256 segmentIndex) internal pure returns (uint40) {
        uint160 addressValue = uint160(addr);

        if (segmentIndex == AddressEntropyConstants.SEGMENT_INDEX_0) {
            return uint40(addressValue & AddressEntropyConstants.SEGMENT_BITMASK);
        } else if (segmentIndex == AddressEntropyConstants.SEGMENT_INDEX_1) {
            return uint40(
                (addressValue >> AddressEntropyConstants.SEGMENT_SHIFT_1) & AddressEntropyConstants.SEGMENT_BITMASK
            );
        } else if (segmentIndex == AddressEntropyConstants.SEGMENT_INDEX_2) {
            return uint40(
                (addressValue >> AddressEntropyConstants.SEGMENT_SHIFT_2) & AddressEntropyConstants.SEGMENT_BITMASK
            );
        } else {
            // segmentIndex == 3
            return uint40(
                (addressValue >> AddressEntropyConstants.SEGMENT_SHIFT_3) & AddressEntropyConstants.SEGMENT_BITMASK
            );
        }
    }

    /// @notice Generates a fallback segment when extraction fails
    /// @dev Creates a unique segment based on timestamp and index
    /// @param segmentIndex The segment index that was being extracted
    /// @return A non-zero 5-byte segment
    function generateFallbackSegment(uint256 segmentIndex) internal view returns (bytes5) {
        // Use hash of block data and segment index to create a fallback
        bytes20 fallbackBytes =
            bytes20(keccak256(abi.encode(block.timestamp, block.number, block.prevrandao, segmentIndex, address(this))));

        // Take the first 5 bytes
        return bytes5(fallbackBytes);
    }

    /// @notice Generates fallback segments for a zero address
    /// @return A fixed-size array of generated segments
    function generateFallbackSegments() internal view returns (bytes5[SEGMENTS_PER_ADDRESS] memory) {
        bytes5[SEGMENTS_PER_ADDRESS] memory segments = [bytes5(0), bytes5(0), bytes5(0), bytes5(0)];

        for (uint256 i = 0; i < SEGMENTS_PER_ADDRESS; i++) {
            segments[i] = bytes5(bytes20(keccak256(abi.encode(block.timestamp, block.number, i))));
        }

        return segments;
    }

    /*//////////////////////////////////////////////////////////////
                         SEGMENT VALIDATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks if a segment index is valid
    /// @param segmentIndex The segment index to check
    /// @return True if the segment index is valid
    function isSegmentIndexValid(uint256 segmentIndex) internal pure returns (bool) {
        return segmentIndex < AddressEntropyConstants.SEGMENTS_PER_ADDRESS;
    }

    /// @notice Checks if a segment is zero
    /// @param segment The segment to check
    /// @return True if the segment is zero
    function isZeroSegment(uint40 segment) internal pure returns (bool) {
        return segment == AddressEntropyConstants.ZERO_SEGMENT;
    }

    /// @notice Checks if a bytes5 value is zero
    /// @param value The bytes5 value to check
    /// @return True if the value is all zeros
    function isZeroByteArray(bytes5 value) internal pure returns (bool) {
        return uint40(value) == AddressEntropyConstants.ZERO_SEGMENT;
    }
}
