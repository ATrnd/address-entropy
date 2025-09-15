// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AbstractAddressEntropy} from "../abstracts/AbstractAddressEntropy.sol";

/**
 * @title AddressDataEntropy
 * @notice Production implementation of address-based entropy generation with segmented extraction
 * @dev Concrete implementation of the AddressEntropy system using all extracted abstractions
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

    /// @notice Initializes the Address Data Entropy contract
    /// @dev Sets up initial state with owner and seed addresses
    /// @param _initialOwner Address that will own and control the contract
    /// @param _seedAddresses Array of addresses to seed the entropy
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
