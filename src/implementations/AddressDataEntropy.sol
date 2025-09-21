// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AbstractAddressEntropy} from "../abstracts/AbstractAddressEntropy.sol";

/**
 * @title AddressDataEntropy
 * @notice Production implementation of address-based entropy generation with segmented extraction
 * @dev Production wrapper for AbstractAddressEntropy with administrative controls
 *      Forms dual-entropy architecture with BlockDataEntropy for comprehensive randomness sources
 * @author ATrnd
 */
contract AddressDataEntropy is AbstractAddressEntropy {

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Local constants for array declarations (Solidity compiler requirement)
    uint256 private constant ADDRESS_ARRAY_SIZE = 3;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes production address entropy contract with seed addresses
    /// @dev Delegates to AbstractAddressEntropy for validation and state initialization
    /// @param _initialOwner Contract owner with administrative control privileges
    /// @param _seedAddresses 3-element array of non-zero addresses for entropy pool initialization
    constructor(
        address _initialOwner,
        address[ADDRESS_ARRAY_SIZE] memory _seedAddresses
    ) AbstractAddressEntropy(_initialOwner, _seedAddresses) {
        // Constructor logic is handled by AbstractAddressEntropy
        // All functionality is inherited from the abstract base
    }

    /*//////////////////////////////////////////////////////////////
                        INHERITED FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    // All functionality inherited from AbstractAddressEntropy
    // Entry point: getEntropy(uint256 salt)
    // State inspection functions moved to AddressDataEntropyTestProxy for security
}
