// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IAddressFallbackHandler
 * @notice Interface for handling fallback scenarios in address-based entropy generation
 * @dev Defines the contract for error tracking, fallback coordination, and emergency entropy generation
 * @author ATrnd
 */
interface IAddressFallbackHandler {

    /*//////////////////////////////////////////////////////////////
                         ERROR TRACKING
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the count for a specific error in a specific component
    /// @param componentId The component to check
    /// @param errorCode The error code to check
    /// @return The count of this specific error in this component
    function getComponentErrorCount(uint8 componentId, uint8 errorCode) external view returns (uint256);

    /// @notice Gets the total errors for a specific component
    /// @param componentId The component to check
    /// @return Total error count for the component
    function getComponentTotalErrorCount(uint8 componentId) external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                   ADDRESS EXTRACTION ERROR COUNTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the count of zero address errors in the address extraction component
    /// @return The error count
    function getAddressExtractionZeroAddressCount() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                   SEGMENT EXTRACTION ERROR COUNTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the count of zero segment errors in the segment extraction component
    /// @return The error count
    function getSegmentExtractionZeroSegmentCount() external view returns (uint256);

    /// @notice Gets the count of out of bounds errors in the segment extraction component
    /// @return The error count
    function getSegmentExtractionOutOfBoundsCount() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                   ENTROPY GENERATION ERROR COUNTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the count of cycle disruption errors in the entropy generation component
    /// @return The error count
    function getEntropyGenerationCycleDisruptionCount() external view returns (uint256);

    /// @notice Gets the count of zero address errors in the entropy generation component
    /// @return The error count
    function getEntropyGenerationZeroAddressCount() external view returns (uint256);

    /// @notice Gets the count of zero segment errors in entropy generation
    /// @return The error count
    function getEntropyGenerationZeroSegmentCount() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                     ACCESS CONTROL ERROR COUNTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the count of orchestrator not configured errors in the access control component
    /// @return The error count
    function getAccessControlOrchestratorNotConfiguredCount() external view returns (uint256);

    /// @notice Gets the count of unauthorized orchestrator errors in the access control component
    /// @return The error count
    function getAccessControlUnauthorizedOrchestratorCount() external view returns (uint256);

    /// @notice Gets the count of orchestrator already configured errors in the access control component
    /// @return The error count
    function getAccessControlOrchestratorAlreadyConfiguredCount() external view returns (uint256);

    /// @notice Gets the count of invalid orchestrator address errors in the access control component
    /// @return The error count
    function getAccessControlInvalidOrchestratorAddressCount() external view returns (uint256);

}
