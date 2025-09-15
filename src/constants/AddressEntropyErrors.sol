// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title AddressEntropyErrors
 * @notice Centralized error definitions for the Address Entropy system
 * @dev Contains all custom errors used across address-based entropy generation components
 * @author ATrnd
 */
library AddressEntropyErrors {

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when an invalid array size is provided
    error AddressEntropy__InvalidArraySize();

    /// @notice Thrown when segment index is out of bounds
    error AddressEntropy__InvalidSegmentIndex();
}
