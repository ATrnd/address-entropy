// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { AddressEntropyConstants } from "../constants/AddressEntropyConstants.sol";

/**
 * @title AddressCyclingLibrary
 * @notice Pure utility functions for index cycling and state management
 * @dev Contains cycling logic extracted from AddressDataEntropy
 * @author ATrnd
 */
library AddressCyclingLibrary {
    /*//////////////////////////////////////////////////////////////
                         INDEX CYCLING
    //////////////////////////////////////////////////////////////*/

    /// @notice Cycles the address index to the next position
    /// @param currentIndex The current address index
    /// @return The next address index in the cycle
    function cycleAddressIndex(uint256 currentIndex) internal pure returns (uint256) {
        return (currentIndex + AddressEntropyConstants.INDEX_INCREMENT) % AddressEntropyConstants.ADDRESS_ARRAY_SIZE;
    }

    /// @notice Cycles the segment index to the next position
    /// @param currentIndex The current segment index
    /// @return The next segment index in the cycle
    function cycleSegmentIndex(uint256 currentIndex) internal pure returns (uint256) {
        return (currentIndex + AddressEntropyConstants.INDEX_INCREMENT) % AddressEntropyConstants.SEGMENTS_PER_ADDRESS;
    }

    /// @notice Cycles the update position to the next slot
    /// @param currentPosition The current update position
    /// @return The next update position in the cycle
    function cycleUpdatePosition(uint256 currentPosition) internal pure returns (uint256) {
        return (currentPosition + AddressEntropyConstants.INDEX_INCREMENT) % AddressEntropyConstants.ADDRESS_ARRAY_SIZE;
    }

    /*//////////////////////////////////////////////////////////////
                         TRANSACTION COUNTER
    //////////////////////////////////////////////////////////////*/

    /// @notice Increments the transaction counter
    /// @param currentCounter The current transaction counter
    /// @return The new transaction counter value
    function incrementTransactionCounter(uint256 currentCounter) internal pure returns (uint256) {
        return currentCounter + AddressEntropyConstants.INDEX_INCREMENT;
    }
}
