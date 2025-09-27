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
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes production address entropy contract with seed addresses
    /// @dev Delegates to AbstractAddressEntropy for validation and state initialization
    /// @param _initialOwner Contract owner with administrative control privileges
    /// @param _seedAddresses 3-element array of non-zero addresses for entropy pool initialization
    constructor(
        address _initialOwner,
        address[3] memory _seedAddresses
    ) AbstractAddressEntropy(_initialOwner, _seedAddresses) {}
    // Constructor logic is handled by AbstractAddressEntropy
    // All functionality is inherited from the abstract base

}
