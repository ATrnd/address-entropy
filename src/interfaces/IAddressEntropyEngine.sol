// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IAddressEntropyEngine
 * @notice Production interface for address-based entropy generation
 * @dev Clean, minimal interface for standalone address entropy engine
 * @author ATrnd
 */
interface IAddressEntropyEngine {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when invalid addresses are provided
    error AddressEntropyEngine__InvalidAddress();
    
    /// @notice Thrown when array size is invalid
    error AddressEntropyEngine__InvalidArraySize();
    
    /// @notice Thrown when caller is not authorized
    error AddressEntropyEngine__Unauthorized();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when entropy is successfully generated
    /// @param requester Address requesting entropy
    /// @param salt Salt used in generation
    /// @param addressIndex Current address index used
    /// @param segmentIndex Current segment index used
    /// @param entropy Generated entropy value
    event EntropyGenerated(
        address indexed requester,
        uint256 indexed salt,
        uint256 addressIndex,
        uint256 segmentIndex,
        bytes32 entropy
    );

    /// @notice Emitted when the entropy address pool is updated
    /// @param position Position in array that was updated
    /// @param oldAddress Previous address at position
    /// @param newAddress New address at position
    event AddressUpdated(
        uint256 indexed position,
        address indexed oldAddress,
        address indexed newAddress
    );

    /// @notice Emitted when fallback entropy generation is triggered
    /// @param reason Reason for fallback
    /// @param fallbackEntropy Generated fallback entropy
    event FallbackTriggered(string reason, bytes32 fallbackEntropy);

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Generates entropy from address data with given salt
    /// @dev Main entropy generation function - combines address segments with salt
    /// @param salt Additional randomness salt
    /// @return Generated entropy as bytes32
    function generateEntropy(uint256 salt) external returns (bytes32);

    /// @notice Gets current state of the entropy engine
    /// @dev Returns indices and counters for monitoring
    /// @return addressIndex Current address being used
    /// @return segmentIndex Current segment being extracted
    /// @return transactionCount Total transactions processed
    /// @return updatePosition Next position to update in address array
    function getState() external view returns (
        uint256 addressIndex,
        uint256 segmentIndex, 
        uint256 transactionCount,
        uint256 updatePosition
    );

    /// @notice Gets the current entropy address pool
    /// @dev Returns array of addresses used for entropy generation
    /// @return addresses Array of current entropy addresses
    function getAddresses() external view returns (address[] memory addresses);

    /// @notice Updates an address in the entropy pool (owner only)
    /// @dev Allows updating specific positions in the address array
    /// @param position Array position to update
    /// @param newAddress New address to use
    function updateAddress(uint256 position, address newAddress) external;
}
