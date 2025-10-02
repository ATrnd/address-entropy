// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IAddressEntropy } from "../interfaces/IAddressEntropy.sol";
import { AddressEntropyConstants } from "../constants/AddressEntropyConstants.sol";
import { AddressSegmentLibrary } from "../libraries/AddressSegmentLibrary.sol";
import { AddressValidationLibrary } from "../libraries/AddressValidationLibrary.sol";
import { AddressCyclingLibrary } from "../libraries/AddressCyclingLibrary.sol";
import { AddressFallbackLibrary } from "../libraries/AddressFallbackLibrary.sol";

/**
 * @title AbstractAddressEntropy
 * @notice Abstract base implementation for address-based entropy generation with triple-cycling
 * @dev Template implementation with 160→40bit address segmentation and cycling state management
 *      Complements BlockDataEntropy for identity-based vs temporal-based entropy requirements
 * @author ATrnd
 */
abstract contract AbstractAddressEntropy is IAddressEntropy, Ownable {
    /*//////////////////////////////////////////////////////////////
                            USING STATEMENTS
    //////////////////////////////////////////////////////////////*/

    using AddressSegmentLibrary for address;
    using AddressSegmentLibrary for uint256;
    using AddressValidationLibrary for address;
    using AddressValidationLibrary for uint256;
    using AddressValidationLibrary for bool;
    using AddressCyclingLibrary for uint256;
    using AddressFallbackLibrary for uint8;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Local constants for array declarations
    uint256 private constant ADDRESS_ARRAY_SIZE = 3;
    uint256 private constant SEGMENTS_PER_ADDRESS = 4;

    /// @notice Address pool for entropy generation with 160→40bit segmentation
    /// @dev Fixed-size array enabling 4×40-bit extractions per address, updated via cycling replacement
    address[ADDRESS_ARRAY_SIZE] internal s_entropyAddresses;

    /// @notice Current position in address pool for segment extraction
    /// @dev Cycles 0→1→2→0 with each entropy request, determines active address for segmentation
    uint256 internal s_currentAddressIndex;

    /// @notice Current 40-bit segment position within address
    /// @dev Cycles 0→1→2→3→0 for bit shifts: 0, 40, 80, 120 bits with each entropy request
    uint256 internal s_currentSegmentIndex;

    /// @notice Next address pool slot for replacement during updates
    /// @dev Cycles 0→1→2→0 independently
    uint256 internal s_nextUpdatePosition;

    /// @notice Monotonic counter for entropy request uniqueness
    /// @dev Increments once per getEntropy() call
    uint256 internal s_transactionCounter;

    /// @notice Granular error tracking for fallback monitoring and debugging
    /// @dev Nested mapping: componentId(1-4) → errorCode(1-10) → count
    mapping(uint8 => mapping(uint8 => uint256)) internal s_componentErrorCounts;

    /// @notice Address of the authorized orchestrator contract
    /// @dev Set once during deployment, immutable thereafter
    address private s_orchestratorAddress;

    /// @notice Flag indicating whether orchestrator has been configured
    /// @dev Prevents multiple configuration attempts
    bool private s_orchestratorSet;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes abstract address entropy with validated seed addresses and cycling state
    /// @dev Validates non-zero seed addresses, initializes entropy pool and cycling indices to zero
    /// @param _initialOwner Contract owner for OpenZeppelin Ownable inheritance
    /// @param _seedAddresses 3-element array of validated non-zero addresses for entropy generation
    constructor(address _initialOwner, address[ADDRESS_ARRAY_SIZE] memory _seedAddresses) Ownable(_initialOwner) {
        // Validate seed addresses - ensure they're not zero
        for (uint256 i = 0; i < ADDRESS_ARRAY_SIZE; i++) {
            if (_seedAddresses[i].isZeroAddress()) {
                revert AddressEntropy__InvalidAddress();
            }
        }

        // Initialize entropy address array with seed addresses
        for (uint256 i = 0; i < ADDRESS_ARRAY_SIZE; i++) {
            s_entropyAddresses[i] = _seedAddresses[i];
        }

        // Initialize counters to zero
        s_currentAddressIndex = AddressEntropyConstants.ZERO_UINT;
        s_currentSegmentIndex = AddressEntropyConstants.ZERO_UINT;
        s_nextUpdatePosition = AddressEntropyConstants.ZERO_UINT;
        s_transactionCounter = AddressEntropyConstants.ZERO_UINT;

        // Initialize access control state
        s_orchestratorAddress = AddressEntropyConstants.ZERO_ADDRESS;
        s_orchestratorSet = false;
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Access control modifier restricting function calls to authorized orchestrator
    /// @dev Uses custom errors and constants following established patterns
    modifier onlyOrchestrator() {
        if (s_orchestratorAddress == AddressEntropyConstants.ZERO_ADDRESS) {
            // NOTE: Cannot track errors here - revert rolls back state changes
            revert AddressEntropy__OrchestratorNotConfigured();
        }
        if (msg.sender != s_orchestratorAddress) {
            // NOTE: Cannot track errors here - revert rolls back state changes
            revert AddressEntropy__UnauthorizedOrchestrator();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Generates entropy from current address data with salt
    /// @dev Triple-cycling state management: advances address index, segment index, and update position
    /// @param salt Additional entropy source for randomness enhancement
    /// @param actualCaller The actual caller address to use for entropy generation (not msg.sender)
    /// @return 32-byte entropy value derived from 40-bit address segment with block and transaction context
    function getEntropy(
        uint256 salt,
        address actualCaller
    )
        external
        virtual
        override
        onlyOrchestrator
        returns (bytes32)
    {
        // Validate actualCaller is not zero address
        if (actualCaller == AddressEntropyConstants.ZERO_ADDRESS) {
            _handleAccessControlFailure(
                AddressEntropyConstants.COMPONENT_ACCESS_CONTROL,
                AddressEntropyConstants.FUNC_GET_ENTROPY_ACCESS_CONTROLLED,
                AddressEntropyConstants.ERROR_INVALID_ORCHESTRATOR_ADDRESS
            );
            revert AddressEntropy__InvalidOrchestratorAddress();
        }
        // Always increment transaction counter exactly once per call
        uint256 currentTx = _incrementTransactionCounter();

        address currentAddress = s_entropyAddresses[s_currentAddressIndex];

        // Check for zero address (should never happen with proper initialization)
        if (currentAddress.isZeroAddress()) {
            _handleFallback(
                AddressEntropyConstants.COMPONENT_ENTROPY_GENERATION,
                AddressEntropyConstants.FUNC_GET_ENTROPY,
                AddressEntropyConstants.ERROR_ZERO_ADDRESS
            );
            return _generateEmergencyEntropy(salt, currentTx);
        }

        // Extract the current address segment for entropy with error checking
        bytes5 currentSegment = _extractAddressSegment(currentAddress, s_currentSegmentIndex);

        // Validate the extracted segment
        if (AddressSegmentLibrary.isZeroByteArray(currentSegment)) {
            _handleFallback(
                AddressEntropyConstants.COMPONENT_ENTROPY_GENERATION,
                AddressEntropyConstants.FUNC_GET_ENTROPY,
                AddressEntropyConstants.ERROR_ENTROPY_ZERO_SEGMENT
            );
            return _generateEmergencyEntropy(salt, currentTx);
        }

        // Generate entropy
        bytes32 entropy = keccak256(
            abi.encode(
                // Extracted segment
                currentSegment,
                s_currentSegmentIndex,
                // Block context for additional entropy
                block.timestamp,
                block.number,
                block.prevrandao,
                block.basefee,
                block.coinbase,
                // Transaction context
                actualCaller,
                salt,
                currentTx,
                // Contract state
                keccak256(abi.encode(s_entropyAddresses))
            )
        );

        emit EntropyGenerated(
            msg.sender, // requester (orchestrator)
            actualCaller, // actual caller used for entropy
            s_currentSegmentIndex,
            block.number
        );

        // Update entropy state for future randomness
        _updateEntropyState(actualCaller);

        return entropy;
    }

    /// @notice Configures the authorized orchestrator address (one-time only)
    /// @dev Can only be called by contract owner and only once
    /// @param _orchestrator Address of the EntropyMachine orchestrator contract
    function setOrchestratorOnce(address _orchestrator) external onlyOwner {
        if (s_orchestratorSet) {
            // NOTE: Cannot track errors here - revert rolls back state changes
            revert AddressEntropy__OrchestratorAlreadyConfigured();
        }

        if (_orchestrator == AddressEntropyConstants.ZERO_ADDRESS) {
            // NOTE: Cannot track errors here - revert rolls back state changes
            revert AddressEntropy__InvalidOrchestratorAddress();
        }

        s_orchestratorAddress = _orchestrator;
        s_orchestratorSet = true;

        emit OrchestratorConfigured(_orchestrator);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the count for a specific error in a specific component
    /// @param componentId The component to check
    /// @param errorCode The error code to check
    /// @return The count of this specific error in this component
    function getComponentErrorCount(
        uint8 componentId,
        uint8 errorCode
    )
        external
        view
        virtual
        override
        returns (uint256)
    {
        return s_componentErrorCounts[componentId][errorCode];
    }

    /// @notice Gets the total errors for a specific component
    /// @param componentId The component to check
    /// @return Total error count for the component
    function getComponentTotalErrorCount(uint8 componentId) external view virtual override returns (uint256) {
        uint256 total = AddressEntropyConstants.ZERO_UINT;
        // Direct access to known error codes instead of loops
        total += s_componentErrorCounts[componentId][AddressEntropyConstants.ERROR_ZERO_ADDRESS];
        total += s_componentErrorCounts[componentId][AddressEntropyConstants.ERROR_ZERO_SEGMENT];
        total += s_componentErrorCounts[componentId][AddressEntropyConstants.ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS];
        total += s_componentErrorCounts[componentId][AddressEntropyConstants.ERROR_UPDATE_CYCLE_DISRUPTION];
        total += s_componentErrorCounts[componentId][AddressEntropyConstants.ERROR_ENTROPY_ZERO_SEGMENT];
        total += s_componentErrorCounts[componentId][AddressEntropyConstants.ERROR_ORCHESTRATOR_NOT_CONFIGURED];
        total += s_componentErrorCounts[componentId][AddressEntropyConstants.ERROR_UNAUTHORIZED_ORCHESTRATOR];
        total += s_componentErrorCounts[componentId][AddressEntropyConstants.ERROR_ORCHESTRATOR_ALREADY_CONFIGURED];
        total += s_componentErrorCounts[componentId][AddressEntropyConstants.ERROR_INVALID_ORCHESTRATOR_ADDRESS];
        return total;
    }

    /// @notice Gets the count of zero address errors in the address extraction component
    /// @return The error count
    function getAddressExtractionZeroAddressCount() external view virtual override returns (uint256) {
        return s_componentErrorCounts[AddressEntropyConstants.COMPONENT_ADDRESS_EXTRACTION][AddressEntropyConstants
            .ERROR_ZERO_ADDRESS];
    }

    /// @notice Gets the count of zero segment errors in the segment extraction component
    /// @return The error count
    function getSegmentExtractionZeroSegmentCount() external view virtual override returns (uint256) {
        return s_componentErrorCounts[AddressEntropyConstants.COMPONENT_SEGMENT_EXTRACTION][AddressEntropyConstants
            .ERROR_ZERO_SEGMENT];
    }

    /// @notice Gets the count of out of bounds errors in the segment extraction component
    /// @return The error count
    function getSegmentExtractionOutOfBoundsCount() external view virtual override returns (uint256) {
        return s_componentErrorCounts[AddressEntropyConstants.COMPONENT_SEGMENT_EXTRACTION][AddressEntropyConstants
            .ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS];
    }

    /// @notice Gets the count of cycle disruption errors in the entropy generation component
    /// @return The error count
    function getEntropyGenerationCycleDisruptionCount() external view virtual override returns (uint256) {
        return s_componentErrorCounts[AddressEntropyConstants.COMPONENT_ENTROPY_GENERATION][AddressEntropyConstants
            .ERROR_UPDATE_CYCLE_DISRUPTION];
    }

    /// @notice Gets the count of zero address errors in the entropy generation component
    /// @return The error count
    function getEntropyGenerationZeroAddressCount() external view virtual override returns (uint256) {
        return s_componentErrorCounts[AddressEntropyConstants.COMPONENT_ENTROPY_GENERATION][AddressEntropyConstants
            .ERROR_ZERO_ADDRESS];
    }

    /// @notice Gets the count of zero segment errors in entropy generation
    /// @return The error count
    function getEntropyGenerationZeroSegmentCount() external view virtual override returns (uint256) {
        return s_componentErrorCounts[AddressEntropyConstants.COMPONENT_ENTROPY_GENERATION][AddressEntropyConstants
            .ERROR_ENTROPY_ZERO_SEGMENT];
    }

    /// @notice Gets the count of orchestrator not configured errors in the access control component
    /// @return The error count
    function getAccessControlOrchestratorNotConfiguredCount() external view virtual override returns (uint256) {
        return s_componentErrorCounts[AddressEntropyConstants.COMPONENT_ACCESS_CONTROL][AddressEntropyConstants
            .ERROR_ORCHESTRATOR_NOT_CONFIGURED];
    }

    /// @notice Gets the count of unauthorized orchestrator errors in the access control component
    /// @return The error count
    function getAccessControlUnauthorizedOrchestratorCount() external view virtual override returns (uint256) {
        return s_componentErrorCounts[AddressEntropyConstants.COMPONENT_ACCESS_CONTROL][AddressEntropyConstants
            .ERROR_UNAUTHORIZED_ORCHESTRATOR];
    }

    /// @notice Gets the count of orchestrator already configured errors in the access control component
    /// @return The error count
    function getAccessControlOrchestratorAlreadyConfiguredCount() external view virtual override returns (uint256) {
        return s_componentErrorCounts[AddressEntropyConstants.COMPONENT_ACCESS_CONTROL][AddressEntropyConstants
            .ERROR_ORCHESTRATOR_ALREADY_CONFIGURED];
    }

    /// @notice Gets the count of invalid orchestrator address errors in the access control component
    /// @return The error count
    function getAccessControlInvalidOrchestratorAddressCount() external view virtual override returns (uint256) {
        return s_componentErrorCounts[AddressEntropyConstants.COMPONENT_ACCESS_CONTROL][AddressEntropyConstants
            .ERROR_INVALID_ORCHESTRATOR_ADDRESS];
    }

    /// @notice Gets the configured orchestrator address
    /// @dev Returns zero address if not configured
    /// @return The orchestrator address
    function getOrchestrator() external view virtual override returns (address) {
        return s_orchestratorAddress;
    }

    /// @notice Checks if orchestrator has been configured
    /// @dev Uses constants for validation
    /// @return True if orchestrator is set and valid
    function isOrchestratorConfigured() external view virtual override returns (bool) {
        return s_orchestratorSet && s_orchestratorAddress != AddressEntropyConstants.ZERO_ADDRESS;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Extracts a specific segment from an address with validation
    /// @dev Internal function used by entropy generation process
    /// @param addr The address to extract from
    /// @param segmentIndex Which segment to extract (0-3)
    /// @return The extracted 5-byte segment
    function _extractAddressSegment(address addr, uint256 segmentIndex) internal virtual returns (bytes5) {
        // Check for zero address
        if (addr.isZeroAddress()) {
            _handleFallback(
                AddressEntropyConstants.COMPONENT_ADDRESS_EXTRACTION,
                AddressEntropyConstants.FUNC_EXTRACT_ADDRESS_SEGMENT,
                AddressEntropyConstants.ERROR_ZERO_ADDRESS
            );
            return AddressSegmentLibrary.generateFallbackSegment(segmentIndex);
        }

        // Validate segment index
        if (!AddressSegmentLibrary.isSegmentIndexValid(segmentIndex)) {
            _handleFallback(
                AddressEntropyConstants.COMPONENT_SEGMENT_EXTRACTION,
                AddressEntropyConstants.FUNC_EXTRACT_ADDRESS_SEGMENT,
                AddressEntropyConstants.ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS
            );
            // Reset segment index to valid state for future operations
            s_currentSegmentIndex = AddressEntropyConstants.ZERO_UINT;
            return AddressSegmentLibrary.generateFallbackSegment(AddressEntropyConstants.SEGMENT_INDEX_0);
        }

        // Extract segment using the appropriate shift
        uint40 extractedSegment = AddressSegmentLibrary.extractSegmentWithShift(addr, segmentIndex);

        // Check for zero segment
        if (AddressSegmentLibrary.isZeroSegment(extractedSegment)) {
            _handleFallback(
                AddressEntropyConstants.COMPONENT_SEGMENT_EXTRACTION,
                AddressEntropyConstants.FUNC_EXTRACT_ADDRESS_SEGMENT,
                AddressEntropyConstants.ERROR_ZERO_SEGMENT
            );
            return AddressSegmentLibrary.generateFallbackSegment(segmentIndex);
        }

        return bytes5(extractedSegment);
    }

    /// @notice Updates the entropy state after generating entropy
    /// @dev Implements double-cycling pattern for both iterators
    /// @param actualCaller The actual caller address to use for entropy array updates
    function _updateEntropyState(address actualCaller) internal {
        // Check for errors directly
        if (actualCaller == AddressEntropyConstants.ZERO_ADDRESS) {
            _handleFallback(
                AddressEntropyConstants.COMPONENT_ENTROPY_GENERATION,
                AddressEntropyConstants.FUNC_UPDATE_ENTROPY_STATE,
                AddressEntropyConstants.ERROR_ZERO_ADDRESS
            );
            return; // Exit early without cycling
        }

        // Try to update an address in the entropy array
        bool updated = _tryUpdateAddress(actualCaller);

        // Only advance indices if no errors occurred
        s_currentAddressIndex = s_currentAddressIndex.cycleAddressIndex();
        s_currentSegmentIndex = s_currentSegmentIndex.cycleSegmentIndex();

        // Only advance the update position if we actually updated an address
        if (updated) {
            s_nextUpdatePosition = s_nextUpdatePosition.cycleUpdatePosition();
        }
    }

    /// @notice Attempts to update an address in the entropy array
    /// @dev Only updates if the address is not already in the array and not zero
    /// @param newAddress The address to potentially add to the array
    /// @return Whether an address was updated
    function _tryUpdateAddress(address newAddress) internal returns (bool) {
        // Ignore zero address
        if (newAddress.isZeroAddress()) {
            return false;
        }

        for (uint256 i = 0; i < ADDRESS_ARRAY_SIZE; i++) {
            if (s_entropyAddresses[i] == newAddress) {
                return false; // Address already present, no update needed
            }
        }

        // If address is not present, update the next position
        address oldAddress = s_entropyAddresses[s_nextUpdatePosition];
        s_entropyAddresses[s_nextUpdatePosition] = newAddress;

        emit EntropyAddressUpdated(s_nextUpdatePosition, oldAddress, newAddress);

        return true; // Address was updated
    }

    /// @notice Increments the transaction counter and returns the new value
    /// @return The new transaction counter value
    function _incrementTransactionCounter() internal returns (uint256) {
        s_transactionCounter = s_transactionCounter.incrementTransactionCounter();
        return s_transactionCounter;
    }

    /// @notice Handles a fallback event with tracking and event emission
    /// @dev Increments component-specific error counter and emits event
    /// @param componentId The component where the fallback occurred
    /// @param functionName The function where the fallback occurred
    /// @param errorCode The specific error code
    function _handleFallback(uint8 componentId, string memory functionName, uint8 errorCode) internal {
        // Increment the specific error counter for this component
        _incrementComponentErrorCount(componentId, errorCode);

        // Get component name for the event
        string memory componentName = _getComponentName(componentId);

        // Emit the event
        emit SafetyFallbackTriggered(
            keccak256(bytes(componentName)), keccak256(bytes(functionName)), errorCode, componentName, functionName
        );
    }

    /// @notice Internal helper for access control error handling
    /// @dev Follows established error tracking pattern
    /// @param componentId Component where error occurred
    /// @param functionName Function where error occurred
    /// @param errorCode Specific error code
    function _handleAccessControlFailure(uint8 componentId, string memory functionName, uint8 errorCode) internal {
        _handleFallback(componentId, functionName, errorCode);
    }

    /// @notice Increments the error counter for a specific component and error type
    /// @dev Used for tracking specific fallback scenarios
    /// @param componentId The component ID where the error occurred
    /// @param errorCode The specific error code
    /// @return The new error count for this component/error combination
    function _incrementComponentErrorCount(uint8 componentId, uint8 errorCode) internal returns (uint256) {
        s_componentErrorCounts[componentId][errorCode] =
            AddressFallbackLibrary.incrementComponentErrorCount(s_componentErrorCounts[componentId][errorCode]);
        return s_componentErrorCounts[componentId][errorCode];
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Generates emergency entropy when normal entropy generation fails
    /// @dev Falls back to alternative entropy sources
    /// @param salt Additional entropy source provided by caller
    /// @param txCounter The current transaction counter
    /// @return Emergency entropy value
    function _generateEmergencyEntropy(uint256 salt, uint256 txCounter) internal view returns (bytes32) {
        return AddressFallbackLibrary.generateEmergencyEntropy(
            salt,
            txCounter,
            s_componentErrorCounts[AddressEntropyConstants.COMPONENT_ADDRESS_EXTRACTION][AddressEntropyConstants
                .ERROR_ZERO_ADDRESS],
            s_componentErrorCounts[AddressEntropyConstants.COMPONENT_SEGMENT_EXTRACTION][AddressEntropyConstants
                .ERROR_ZERO_SEGMENT]
        );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Converts a component ID to its string name
    /// @param componentId The component identifier
    /// @return The string name of the component
    function _getComponentName(uint8 componentId) internal pure returns (string memory) {
        return AddressFallbackLibrary.getComponentName(componentId);
    }
}
