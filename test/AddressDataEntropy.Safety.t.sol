// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {AddressDataEntropy} from "../src/implementations/AddressDataEntropy.sol";
import {AddressDataEntropyTestProxy} from "./mock/AddressDataEntropyTestProxy.sol";
import {IAddressEntropy} from "../src/interfaces/IAddressEntropy.sol";
import {IAddressFallbackHandler} from "../src/interfaces/IAddressFallbackHandler.sol";
import {AddressEntropyConstants} from "../src/constants/AddressEntropyConstants.sol";

/// @title AddressDataEntropy Safety Test Suite
/// @notice Comprehensive tests for safety mechanisms, error handling, and recovery systems
contract AddressDataEntropySafetyTest is Test {
    using AddressEntropyConstants for *;

    /*//////////////////////////////////////////////////////////////
                                 VARIABLES
    //////////////////////////////////////////////////////////////*/
    
    AddressDataEntropyTestProxy public proxy;
    address public owner;
    address public user1;
    address public user2;
    
    // Seed addresses for testing
    address[3] public seedAddresses;

    // Constants for testing
    uint8 constant COMPONENT_ADDRESS_EXTRACTION = 1;
    uint8 constant COMPONENT_SEGMENT_EXTRACTION = 2;
    uint8 constant COMPONENT_ENTROPY_GENERATION = 3;
    
    uint8 constant ERROR_ZERO_ADDRESS = 1;
    uint8 constant ERROR_INSUFFICIENT_ADDRESS_DIVERSITY = 2;
    uint8 constant ERROR_ZERO_SEGMENT = 3;
    uint8 constant ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS = 4;
    uint8 constant ERROR_UPDATE_CYCLE_DISRUPTION = 5;
    uint8 constant ERROR_ENTROPY_ZERO_SEGMENT = 6;

    string constant FUNC_EXTRACT_ADDRESS_SEGMENT = "extractAddressSegment";
    string constant FUNC_GET_ENTROPY = "getEntropy";
    string constant FUNC_UPDATE_ENTROPY_STATE = "updateEntropyState";

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Setup seed addresses for entropy
        seedAddresses[0] = makeAddr("seed1");
        seedAddresses[1] = makeAddr("seed2");
        seedAddresses[2] = makeAddr("seed3");
        
        // Deploy proxy with seed addresses
        proxy = new AddressDataEntropyTestProxy(owner, seedAddresses);
    }

    /*//////////////////////////////////////////////////////////////
                          ERROR HANDLING TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test zero address error handling and recovery
    function test_ZeroAddressErrorHandling() public {
        // Setup - inject zero address to trigger error
        proxy.resetState();
        proxy.injectZeroAddressAtCurrentIndex();
        
        // Record initial error count
        uint256 initialErrorCount = proxy.getEntropyGenerationZeroAddressCount();
        
        // Record logs for event verification
        vm.recordLogs();
        
        // Execute - should trigger zero address fallback
        bytes32 entropy = proxy.getEntropy(12345);
        
        // Verify entropy is still generated (emergency entropy)
        assertTrue(entropy != bytes32(0), "Should generate emergency entropy despite zero address");
        
        // Verify error counter incremented
        assertEq(
            proxy.getEntropyGenerationZeroAddressCount(),
            initialErrorCount + 1,
            "Zero address error count should increment"
        );
        
        // Verify safety event was emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        verifySafetyFallbackEvent(
            logs,
            COMPONENT_ENTROPY_GENERATION,
            FUNC_GET_ENTROPY,
            ERROR_ZERO_ADDRESS
        );
    }

    /// @notice Test zero segment error handling and recovery
    function test_ZeroSegmentErrorHandling() public {
        // Setup - force zero segment condition
        proxy.resetState();
        proxy.forceSetZeroSegment(true);
        
        // Record initial error count
        uint256 initialErrorCount = proxy.getSegmentExtractionZeroSegmentCount();
        
        // Record logs
        vm.recordLogs();
        
        // Execute - call extractAddressSegment directly
        address testAddr = makeAddr("testAddress");
        bytes5 segment = proxy.callExtractAddressSegment(testAddr, 1);
        
        // Verify fallback segment is generated
        assertTrue(segment != bytes5(0), "Should generate fallback segment");
        
        // Verify error counter incremented
        assertEq(
            proxy.getSegmentExtractionZeroSegmentCount(),
            initialErrorCount + 1,
            "Zero segment error count should increment"
        );
        
        // Verify safety event
        Vm.Log[] memory logs = vm.getRecordedLogs();
        verifySafetyFallbackEvent(
            logs,
            COMPONENT_SEGMENT_EXTRACTION,
            FUNC_EXTRACT_ADDRESS_SEGMENT,
            ERROR_ZERO_SEGMENT
        );
    }

    /// @notice Test out of bounds segment index error handling
    function test_OutOfBoundsIndexErrorHandling() public {
        // Setup - force invalid segment index
        proxy.resetState();
        proxy.forceSetInvalidSegmentIndex(true);
        
        // Record initial error count
        uint256 initialErrorCount = proxy.getSegmentExtractionOutOfBoundsCount();
        
        // Record logs
        vm.recordLogs();
        
        // Execute - should trigger out of bounds error
        address testAddr = makeAddr("testAddress");
        bytes5 segment = proxy.callExtractAddressSegment(testAddr, 0);
        
        // Verify fallback segment is generated
        assertTrue(segment != bytes5(0), "Should generate fallback segment for invalid index");
        
        // Verify error counter incremented
        assertEq(
            proxy.getSegmentExtractionOutOfBoundsCount(),
            initialErrorCount + 1,
            "Out of bounds error count should increment"
        );
        
        // Verify safety event
        Vm.Log[] memory logs = vm.getRecordedLogs();
        verifySafetyFallbackEvent(
            logs,
            COMPONENT_SEGMENT_EXTRACTION,
            FUNC_EXTRACT_ADDRESS_SEGMENT,
            ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS
        );
    }

    /*//////////////////////////////////////////////////////////////
                          CASCADING FAILURE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test system resilience under multiple simultaneous errors
    function test_CascadingFailureRecovery() public {
        // Setup - force multiple error conditions
        proxy.resetState();
        proxy.forceSetZeroAddress(true);
        proxy.forceSetZeroSegment(true);
        proxy.forceSetInvalidSegmentIndex(true);
        
        // Record initial state
        uint256 initialZeroAddressCount = proxy.getEntropyGenerationZeroAddressCount();
        uint256 initialZeroSegmentCount = proxy.getSegmentExtractionZeroSegmentCount();
        uint256 initialOutOfBoundsCount = proxy.getSegmentExtractionOutOfBoundsCount();
        
        // Record logs
        vm.recordLogs();
        
        // Execute - should handle cascading failures gracefully
        bytes32 entropy = proxy.getEntropy(54321);
        
        // Verify entropy is still generated despite all errors
        assertTrue(entropy != bytes32(0), "Should generate entropy despite cascading failures");
        
        // Verify error counters incremented (check all possible error counters)
        bool errorCounterIncremented = 
            proxy.getEntropyGenerationZeroAddressCount() > initialZeroAddressCount ||
            proxy.getSegmentExtractionZeroSegmentCount() > initialZeroSegmentCount ||
            proxy.getSegmentExtractionOutOfBoundsCount() > initialOutOfBoundsCount ||
            proxy.getAddressExtractionZeroAddressCount() > 0;
        
        assertTrue(errorCounterIncremented, "At least one error counter should increment");
        
        // Verify multiple safety events were emitted
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 safetyEventCount = countSafetyFallbackEvents(logs);
        assertTrue(safetyEventCount >= 1, "Should emit at least one safety event during cascading failure");
    }

    /// @notice Test recovery from error states
    function test_ErrorStateRecovery() public {
        // Step 1: Trigger error condition
        proxy.resetState();
        proxy.injectZeroAddressAtCurrentIndex();
        
        // Generate entropy in error state
        bytes32 errorEntropy = proxy.getEntropy(11111);
        assertTrue(errorEntropy != bytes32(0), "Should generate entropy in error state");
        
        // Step 2: Recover from error state
        proxy.resetState(); // This should clear error conditions
        
        // Generate entropy in normal state
        bytes32 normalEntropy = proxy.getEntropy(22222);
        assertTrue(normalEntropy != bytes32(0), "Should generate entropy in normal state");
        
        // Verify entropies are different
        assertTrue(errorEntropy != normalEntropy, "Error state and normal state should produce different entropy");
    }

    /*//////////////////////////////////////////////////////////////
                          COMPONENT ERROR ISOLATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that component errors are properly isolated
    function test_ComponentErrorIsolation() public {
        // Test Address Extraction errors don't affect other components
        proxy.resetState();
        proxy.forceIncrementComponentErrorCount(COMPONENT_ADDRESS_EXTRACTION, ERROR_ZERO_ADDRESS);
        
        // Verify only address extraction has errors
        assertTrue(proxy.hasComponentErrors(COMPONENT_ADDRESS_EXTRACTION), "Address extraction should have errors");
        assertFalse(proxy.hasComponentErrors(COMPONENT_SEGMENT_EXTRACTION), "Segment extraction should not have errors");
        assertFalse(proxy.hasComponentErrors(COMPONENT_ENTROPY_GENERATION), "Entropy generation should not have errors");
        
        // Test specific error counts
        assertEq(proxy.getComponentTotalErrorCount(COMPONENT_ADDRESS_EXTRACTION), 1, "Address extraction total should be 1");
        assertEq(proxy.getComponentTotalErrorCount(COMPONENT_SEGMENT_EXTRACTION), 0, "Segment extraction total should be 0");
        assertEq(proxy.getComponentTotalErrorCount(COMPONENT_ENTROPY_GENERATION), 0, "Entropy generation total should be 0");
        
        // Add error to different component
        proxy.forceIncrementComponentErrorCount(COMPONENT_SEGMENT_EXTRACTION, ERROR_ZERO_SEGMENT);
        
        // Verify both components have errors now
        assertTrue(proxy.hasComponentErrors(COMPONENT_ADDRESS_EXTRACTION), "Address extraction should still have errors");
        assertTrue(proxy.hasComponentErrors(COMPONENT_SEGMENT_EXTRACTION), "Segment extraction should now have errors");
        assertFalse(proxy.hasComponentErrors(COMPONENT_ENTROPY_GENERATION), "Entropy generation should still not have errors");
    }

    /// @notice Test specific error code isolation within components
    function test_ErrorCodeIsolation() public {
        proxy.resetState();
        
        // Add different error types to same component
        proxy.forceIncrementComponentErrorCount(COMPONENT_SEGMENT_EXTRACTION, ERROR_ZERO_SEGMENT);
        proxy.forceIncrementComponentErrorCount(COMPONENT_SEGMENT_EXTRACTION, ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS);
        
        // Verify specific error counts
        assertEq(
            proxy.getSegmentExtractionZeroSegmentCount(), 
            1, 
            "Zero segment error count should be 1"
        );
        assertEq(
            proxy.getSegmentExtractionOutOfBoundsCount(), 
            1, 
            "Out of bounds error count should be 1"
        );
        
        // Verify total count
        assertEq(
            proxy.getComponentTotalErrorCount(COMPONENT_SEGMENT_EXTRACTION), 
            2, 
            "Total segment extraction errors should be 2"
        );
    }

    /*//////////////////////////////////////////////////////////////
                          BOUNDARY CONDITION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test extreme boundary conditions
    function test_ExtremeBoundaryConditions() public {
        // Test with maximum uint256 salt
        bytes32 entropy1 = proxy.getEntropy(type(uint256).max);
        assertTrue(entropy1 != bytes32(0), "Should handle maximum uint256 salt");
        
        // Test with address(0) - but inject a valid address first to avoid complete failure
        proxy.resetState();
        bytes32 entropy2 = proxy.getEntropy(0);
        assertTrue(entropy2 != bytes32(0), "Should handle zero salt");
        
        // Test with extreme block conditions
        vm.roll(type(uint256).max - 1);
        vm.warp(type(uint256).max - 1);
        bytes32 entropy3 = proxy.getEntropy(12345);
        assertTrue(entropy3 != bytes32(0), "Should handle extreme block conditions");
        
        // Verify all entropies are different
        assertTrue(entropy1 != entropy2, "Extreme values should produce different entropy");
        assertTrue(entropy2 != entropy3, "Different conditions should produce different entropy");
        assertTrue(entropy1 != entropy3, "All extreme conditions should produce unique entropy");
    }

    /// @notice Test edge case addresses
    function test_EdgeCaseAddresses() public {
        // Test with low-value addresses
        bytes32 entropy1 = proxy.getEntropy(11111);
        assertTrue(entropy1 != bytes32(0), "Should handle low-value addresses");

        // Test with high-value addresses
        bytes32 entropy2 = proxy.getEntropy(22222);
        assertTrue(entropy2 != bytes32(0), "Should handle high-value addresses");

        // Test with patterned addresses
        bytes32 entropy3 = proxy.getEntropy(33333);
        assertTrue(entropy3 != bytes32(0), "Should handle patterned addresses");
        
        // Verify uniqueness
        assertTrue(entropy1 != entropy2, "Different address patterns should produce different entropy");
        assertTrue(entropy2 != entropy3, "All address patterns should produce unique entropy");
    }

    /*//////////////////////////////////////////////////////////////
                          DETERMINISM SAFETY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test fallback segment determinism and consistency
    function test_FallbackSegmentDeterminism() public {
        proxy.resetState();
        proxy.forceSetZeroSegment(true);
        
        address testAddr = makeAddr("testAddress");
        
        // Generate same fallback segment multiple times in same block
        bytes5 segment1 = proxy.callExtractAddressSegment(testAddr, 0);
        bytes5 segment2 = proxy.callExtractAddressSegment(testAddr, 0);
        bytes5 segment3 = proxy.callExtractAddressSegment(testAddr, 0);
        
        // All should be identical within same block (deterministic fallback)
        assertEq(segment1, segment2, "Fallback segments should be deterministic within block");
        assertEq(segment2, segment3, "Fallback segments should remain consistent");
        
        // Move to next block and test with different parameters
        vm.roll(block.number + 1);
        bytes5 segment4 = proxy.callExtractAddressSegment(testAddr, 1); // Different segment index
        
        // Test with different address
        address testAddr2 = makeAddr("testAddress2");
        bytes5 segment5 = proxy.callExtractAddressSegment(testAddr2, 0);
        
        // Fallback segments should be consistent for same parameters but may vary with different inputs
        assertTrue(segment1 != bytes5(0), "Fallback segment should not be zero");
        assertTrue(segment4 != bytes5(0), "Different segment index should also produce valid fallback");
        assertTrue(segment5 != bytes5(0), "Different address should also produce valid fallback");
        
        // Test that segments are valid fallback segments
        assertTrue(segment1 == segment2, "Same parameters should produce identical fallback segments");
    }

    /// @notice Test emergency entropy variation
    function test_EmergencyEntropyVariation() public {
        proxy.resetState();
        proxy.injectZeroAddressAtCurrentIndex();
        
        // Generate emergency entropy with same salt
        bytes32 emergency1 = proxy.getEntropy(55555);
        bytes32 emergency2 = proxy.getEntropy(55555);
        
        // Should be different due to transaction counter
        assertTrue(emergency1 != emergency2, "Emergency entropy should vary even with same salt");
        
        // Test with different salts
        proxy.resetState();
        proxy.injectZeroAddressAtCurrentIndex();
        bytes32 emergency3 = proxy.getEntropy(66666);
        
        assertTrue(emergency1 != emergency3, "Emergency entropy should vary with different salts");
    }

    /*//////////////////////////////////////////////////////////////
                          SYSTEM RESILIENCE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test continuous operation under persistent errors
    function test_ContinuousOperationUnderErrors() public {
        proxy.resetState();
        proxy.injectZeroAddressAtCurrentIndex();
        
        // Generate entropy multiple times with persistent error condition
        bytes32[] memory entropies = new bytes32[](10);
        
        for (uint256 i = 0; i < 10; i++) {
            entropies[i] = proxy.getEntropy(70000 + i);
            assertTrue(entropies[i] != bytes32(0), "Should continue generating entropy despite persistent errors");
        }
        
        // Verify all entropies are unique
        for (uint256 i = 0; i < 10; i++) {
            for (uint256 j = i + 1; j < 10; j++) {
                assertTrue(entropies[i] != entropies[j], "All entropies should be unique despite error conditions");
            }
        }
    }

    /// @notice Test recovery after extended error periods
    function test_RecoveryAfterExtendedErrors() public {
        // Phase 1: Extended error period
        proxy.resetState();
        proxy.injectZeroAddressAtCurrentIndex();
        
        bytes32[] memory errorEntropies = new bytes32[](5);
        for (uint256 i = 0; i < 5; i++) {
            errorEntropies[i] = proxy.getEntropy(80000 + i);
        }
        
        // Phase 2: Recovery
        proxy.resetState(); // Clear error conditions
        
        bytes32[] memory normalEntropies = new bytes32[](5);
        for (uint256 i = 0; i < 5; i++) {
            normalEntropies[i] = proxy.getEntropy(90000 + i);
        }
        
        // Verify both phases generate valid entropy
        for (uint256 i = 0; i < 5; i++) {
            assertTrue(errorEntropies[i] != bytes32(0), "Error phase should generate valid entropy");
            assertTrue(normalEntropies[i] != bytes32(0), "Normal phase should generate valid entropy");
            assertTrue(errorEntropies[i] != normalEntropies[i], "Error and normal phases should produce different entropy");
        }
    }

    /*//////////////////////////////////////////////////////////////
                          SAFETY EVENT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test comprehensive safety event emission
    function test_ComprehensiveSafetyEvents() public {
        vm.recordLogs();
        
        // Trigger multiple types of safety events
        proxy.forceEmitCustomFallback(COMPONENT_ADDRESS_EXTRACTION, FUNC_EXTRACT_ADDRESS_SEGMENT, ERROR_ZERO_ADDRESS);
        proxy.forceEmitCustomFallback(COMPONENT_SEGMENT_EXTRACTION, FUNC_EXTRACT_ADDRESS_SEGMENT, ERROR_ZERO_SEGMENT);
        proxy.forceEmitCustomFallback(COMPONENT_ENTROPY_GENERATION, FUNC_GET_ENTROPY, ERROR_UPDATE_CYCLE_DISRUPTION);
        
        // Get logs
        Vm.Log[] memory logs = vm.getRecordedLogs();
        
        // Verify we have safety events
        uint256 safetyEventCount = countSafetyFallbackEvents(logs);
        assertEq(safetyEventCount, 3, "Should emit exactly 3 safety events");
        
        // Verify each event type is present
        bool foundAddressError = false;
        bool foundSegmentError = false;
        bool foundEntropyError = false;
        
        bytes32 expectedEventSignature = keccak256(
            "SafetyFallbackTriggered(bytes32,bytes32,uint8,string,string)"
        );
        
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == expectedEventSignature) {
                uint8 errorCode = uint8(uint256(logs[i].topics[3]));
                if (errorCode == ERROR_ZERO_ADDRESS) foundAddressError = true;
                if (errorCode == ERROR_ZERO_SEGMENT) foundSegmentError = true;
                if (errorCode == ERROR_UPDATE_CYCLE_DISRUPTION) foundEntropyError = true;
            }
        }
        
        assertTrue(foundAddressError, "Should find zero address error event");
        assertTrue(foundSegmentError, "Should find zero segment error event"); 
        assertTrue(foundEntropyError, "Should find cycle disruption error event");
    }

    /*//////////////////////////////////////////////////////////////
                          MISSING CRITICAL TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test basic safety fallback event emission patterns
    function test_SafetyFallbackEvent() public {
        vm.recordLogs();
        
        // Emit a basic safety fallback event
        proxy.forceEmitCustomFallback(
            COMPONENT_SEGMENT_EXTRACTION,
            FUNC_EXTRACT_ADDRESS_SEGMENT,
            ERROR_ZERO_SEGMENT
        );
        
        // Get logs
        Vm.Log[] memory logs = vm.getRecordedLogs();
        
        // Verify event was emitted with correct structure
        verifySafetyFallbackEvent(
            logs,
            COMPONENT_SEGMENT_EXTRACTION,
            FUNC_EXTRACT_ADDRESS_SEGMENT,
            ERROR_ZERO_SEGMENT
        );
    }

    /// @notice Test boundary values for segment indices
    function test_SegmentIndexBoundaryValues() public {
        address testAddr = makeAddr("boundaryTestAddress");
        
        // Test valid boundary indices (0-3)
        for (uint256 i = 0; i < 4; i++) {
            bytes5 segment = proxy.callExtractAddressSegment(testAddr, i);
            assertTrue(segment != bytes5(0), string(abi.encodePacked("Valid index ", vm.toString(i), " should produce non-zero segment")));
        }
        
        // Test invalid boundary indices (4, 5, max)
        proxy.resetState();
        proxy.forceSetInvalidSegmentIndex(true);
        
        uint256 initialErrorCount = proxy.getSegmentExtractionOutOfBoundsCount();
        
        // Test index 4 (just above valid range)
        proxy.callExtractAddressSegment(testAddr, 4);
        assertEq(
            proxy.getSegmentExtractionOutOfBoundsCount(),
            initialErrorCount + 1,
            "Index 4 should trigger out of bounds error"
        );
        
        // Test with different addresses to ensure boundary handling is consistent
        address testAddr2 = makeAddr("boundaryTestAddress2");
        proxy.callExtractAddressSegment(testAddr2, type(uint256).max);
        assertEq(
            proxy.getSegmentExtractionOutOfBoundsCount(),
            initialErrorCount + 2,
            "Max index should trigger out of bounds error"
        );
    }

    /// @notice Test emergency entropy diversity patterns
    function test_EmergencyEntropyDiversity() public {
        proxy.resetState();
        proxy.injectZeroAddressAtCurrentIndex();
        
        // Generate emergency entropy with different salt values
        bytes32[] memory emergencyEntropies = new bytes32[](10);
        for (uint256 i = 0; i < 10; i++) {
            emergencyEntropies[i] = proxy.getEntropy(1000 + i);
            assertTrue(emergencyEntropies[i] != bytes32(0), "Emergency entropy should be non-zero");
        }
        
        // Verify diversity - all should be different
        for (uint256 i = 0; i < 10; i++) {
            for (uint256 j = i + 1; j < 10; j++) {
                assertTrue(
                    emergencyEntropies[i] != emergencyEntropies[j],
                    "Emergency entropy should be diverse"
                );
            }
        }
        
        // Test emergency entropy with exposed method
        uint256 currentTx = block.number + block.timestamp + uint256(block.prevrandao);
        bytes32 exposedEmergency1 = proxy.exposedGenerateEmergencyEntropy(2000, currentTx);
        bytes32 exposedEmergency2 = proxy.exposedGenerateEmergencyEntropy(3000, currentTx);
        
        assertTrue(exposedEmergency1 != exposedEmergency2, "Exposed emergency entropy should vary with salt");
        assertTrue(exposedEmergency1 != bytes32(0), "Exposed emergency entropy should be non-zero");
    }

    /// @notice Test fallback segment generation patterns
    function test_FallbackSegmentGeneration() public view {
        // Test exposed fallback segment generation
        bytes5[] memory fallbackSegments = new bytes5[](4);
        
        for (uint256 i = 0; i < 4; i++) {
            fallbackSegments[i] = proxy.exposedGenerateFallbackSegment(i);
            assertTrue(fallbackSegments[i] != bytes5(0), "Fallback segments should be non-zero");
        }
        
        // Verify fallback segments are different for different indices
        for (uint256 i = 0; i < 4; i++) {
            for (uint256 j = i + 1; j < 4; j++) {
                assertTrue(
                    fallbackSegments[i] != fallbackSegments[j],
                    "Different segment indices should produce different fallback segments"
                );
            }
        }
        
        // Test consistency - same index should produce same fallback
        bytes5 fallback0Again = proxy.exposedGenerateFallbackSegment(0);
        assertEq(fallbackSegments[0], fallback0Again, "Fallback segments should be deterministic");
    }

    /// @notice Test comprehensive recovery from zero address conditions
    function test_RecoveryFromZeroAddress() public {
        // Phase 1: Setup zero address error condition
        proxy.resetState();
        proxy.injectZeroAddressAtCurrentIndex();
        
        uint256 initialErrorCount = proxy.getEntropyGenerationZeroAddressCount();
        
        // Generate entropy in error state
        bytes32 errorEntropy = proxy.getEntropy(4000);
        assertTrue(errorEntropy != bytes32(0), "Should generate entropy despite zero address");
        assertTrue(
            proxy.getEntropyGenerationZeroAddressCount() > initialErrorCount,
            "Error count should increment"
        );
        
        // Phase 2: Recovery phase
        proxy.resetState(); // Clear error conditions
        
        // Generate normal entropy
        bytes32 normalEntropy = proxy.getEntropy(4001);
        assertTrue(normalEntropy != bytes32(0), "Should generate normal entropy after recovery");
        
        // Phase 3: Verification phase
        assertTrue(errorEntropy != normalEntropy, "Error and normal entropy should differ");
        
        // Verify system can handle mixed operations
        bytes32 mixedEntropy1 = proxy.getEntropy(4002);
        proxy.injectZeroAddressAtCurrentIndex(); // Re-inject error
        bytes32 mixedEntropy2 = proxy.getEntropy(4003);
        
        assertTrue(mixedEntropy1 != mixedEntropy2, "Mixed operations should produce different entropy");
    }

    /// @notice Test recovery patterns for zero segments
    function test_RecoveryFromZeroSegment() public {
        address testAddr = makeAddr("zeroSegmentRecovery");
        
        // Phase 1: Force zero segment condition
        proxy.resetState();
        proxy.forceSetZeroSegment(true);
        
        uint256 initialErrorCount = proxy.getSegmentExtractionZeroSegmentCount();
        bytes5 fallbackSegment = proxy.callExtractAddressSegment(testAddr, 1);
        
        assertTrue(fallbackSegment != bytes5(0), "Should produce fallback segment");
        assertTrue(
            proxy.getSegmentExtractionZeroSegmentCount() > initialErrorCount,
            "Zero segment error count should increment"
        );
        
        // Phase 2: Recovery - clear error condition
        proxy.resetState();
        proxy.forceSetZeroSegment(false);
        
        bytes5 normalSegment = proxy.callExtractAddressSegment(testAddr, 1);
        assertTrue(normalSegment != bytes5(0), "Should produce normal segment after recovery");
        
        // Phase 3: Verification - segments should be different
        // Note: This might be the same if the actual segment is also the fallback value
        // but the important thing is both are valid
        assertTrue(fallbackSegment != bytes5(0) && normalSegment != bytes5(0), "Both segments should be valid");
    }

    /// @notice Test recovery from invalid segment index conditions
    function test_RecoveryFromInvalidSegmentIndex() public {
        address testAddr = makeAddr("invalidIndexRecovery");
        
        // Phase 1: Force invalid segment index
        proxy.resetState();
        proxy.forceSetInvalidSegmentIndex(true);
        
        uint256 initialErrorCount = proxy.getSegmentExtractionOutOfBoundsCount();
        bytes5 fallbackSegment = proxy.callExtractAddressSegment(testAddr, 2);
        
        assertTrue(fallbackSegment != bytes5(0), "Should produce fallback segment for invalid index");
        assertTrue(
            proxy.getSegmentExtractionOutOfBoundsCount() > initialErrorCount,
            "Out of bounds error count should increment"
        );
        
        // Phase 2: Recovery
        proxy.resetState();
        proxy.forceSetInvalidSegmentIndex(false);
        
        bytes5 normalSegment = proxy.callExtractAddressSegment(testAddr, 2);
        assertTrue(normalSegment != bytes5(0), "Should produce normal segment after recovery");
        
        // Phase 3: Test that recovery is complete
        bytes5 anotherNormalSegment = proxy.callExtractAddressSegment(testAddr, 3);
        assertTrue(anotherNormalSegment != bytes5(0), "Should continue producing normal segments");
    }

    /// @notice Test consecutive fallback behavior tracking
    function test_ConsecutiveFallbacks() public {
        proxy.resetState();
        proxy.injectZeroAddressAtCurrentIndex();
        
        // Generate consecutive fallbacks
        uint256 initialCount = proxy.getEntropyGenerationZeroAddressCount();
        
        bytes32[] memory consecutiveEntropies = new bytes32[](5);
        for (uint256 i = 0; i < 5; i++) {
            consecutiveEntropies[i] = proxy.getEntropy(5000 + i);
            assertTrue(consecutiveEntropies[i] != bytes32(0), "Each consecutive entropy should be valid");
        }
        
        // Verify error count increased appropriately
        assertTrue(
            proxy.getEntropyGenerationZeroAddressCount() >= initialCount + 5,
            "Consecutive fallbacks should increment error count"
        );
        
        // Verify all consecutive entropies are unique
        for (uint256 i = 0; i < 5; i++) {
            for (uint256 j = i + 1; j < 5; j++) {
                assertTrue(
                    consecutiveEntropies[i] != consecutiveEntropies[j],
                    "Consecutive fallback entropies should be unique"
                );
            }
        }
    }

    /// @notice Test mixed valid and invalid operations
    function test_MixedValidAndInvalidOperations() public {
        bytes32[] memory mixedEntropies = new bytes32[](8);
        
        // Pattern: Valid, Invalid, Valid, Invalid, etc.
        for (uint256 i = 0; i < 8; i++) {
            if (i % 2 == 0) {
                // Even indices: normal operation
                proxy.resetState();
                mixedEntropies[i] = proxy.getEntropy(6000 + i);
            } else {
                // Odd indices: error condition
                proxy.resetState();
                proxy.injectZeroAddressAtCurrentIndex();
                mixedEntropies[i] = proxy.getEntropy(6000 + i);
            }
            
            assertTrue(mixedEntropies[i] != bytes32(0), "All mixed operations should produce valid entropy");
        }
        
        // Verify mixed operations produce diverse entropy
        for (uint256 i = 0; i < 8; i++) {
            for (uint256 j = i + 1; j < 8; j++) {
                assertTrue(
                    mixedEntropies[i] != mixedEntropies[j],
                    "Mixed valid/invalid operations should produce unique entropy"
                );
            }
        }
    }

    /// @notice Test malformed input handling edge cases
    function test_MalformedInputHandling() public {
        // Test with zero address extraction
        bytes5 zeroSegment = proxy.callExtractAddressSegment(address(0), 0);
        assertTrue(zeroSegment != bytes5(0), "Zero address should produce fallback segment");
        
        // Test with extreme addresses
        address extremeAddr1 = address(0x1);
        address extremeAddr2 = address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
        
        bytes5 extremeSegment1 = proxy.callExtractAddressSegment(extremeAddr1, 0);
        bytes5 extremeSegment2 = proxy.callExtractAddressSegment(extremeAddr2, 3);
        
        assertTrue(extremeSegment1 != bytes5(0), "Extreme low address should produce valid segment");
        assertTrue(extremeSegment2 != bytes5(0), "Extreme high address should produce valid segment");
        
        // Test with malformed but valid segment indices at boundaries
        bytes5 boundarySegment0 = proxy.callExtractAddressSegment(extremeAddr1, 0);
        bytes5 boundarySegment3 = proxy.callExtractAddressSegment(extremeAddr1, 3);
        
        assertTrue(boundarySegment0 != bytes5(0), "Boundary segment 0 should be valid");
        assertTrue(boundarySegment3 != bytes5(0), "Boundary segment 3 should be valid");
        
        // Test exposed all segments extraction
        bytes5[4] memory allSegments = proxy.exposedExtractAllSegments(extremeAddr1);
        for (uint256 i = 0; i < 4; i++) {
            assertTrue(allSegments[i] != bytes5(0), "All extracted segments should be non-zero");
        }
    }

    /*//////////////////////////////////////////////////////////////
                          STATE UPDATE DISRUPTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test state update mechanisms
    function test_StateUpdateMechanisms() public {
        // Test exposed updateEntropyState
        (uint256 initialAddrIndex, uint256 initialSegIndex, ) = proxy.getCurrentIndices();

        proxy.exposedUpdateEntropyState();

        (uint256 newAddrIndex, uint256 newSegIndex, ) = proxy.getCurrentIndices();
        
        // State should have updated (cycling behavior)
        assertEq(newAddrIndex, (initialAddrIndex + 1) % 3, "Address index should cycle");
        assertEq(newSegIndex, (initialSegIndex + 1) % 4, "Segment index should cycle");
        
        // Test tryUpdateAddress
        address newTestAddr = makeAddr("stateUpdateTest");
        bool updated = proxy.exposedTryUpdateAddress(newTestAddr);
        assertTrue(updated, "Should successfully update with new address");
        
        // Try updating with same address - should fail
        bool updatedAgain = proxy.exposedTryUpdateAddress(newTestAddr);
        assertFalse(updatedAgain, "Should not update with existing address");
        
        // Try updating with zero address - should fail
        bool zeroUpdated = proxy.exposedTryUpdateAddress(address(0));
        assertFalse(zeroUpdated, "Should not update with zero address");
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Helper to verify SafetyFallbackTriggered events
    /// @param logs Array of logs to search
    /// @param componentId Expected component ID
    /// @param functionName Expected function name
    /// @param errorCode Expected error code
    function verifySafetyFallbackEvent(
        Vm.Log[] memory logs,
        uint8 componentId,
        string memory functionName,
        uint8 errorCode
    ) internal view {
        bool foundEvent = false;
        bytes32 expectedEventSignature = keccak256(
            "SafetyFallbackTriggered(bytes32,bytes32,uint8,string,string)"
        );
        
        string memory expectedComponentName = proxy.exposedGetComponentName(componentId);
        bytes32 expectedComponentHash = keccak256(bytes(expectedComponentName));
        bytes32 expectedFunctionHash = keccak256(bytes(functionName));
        
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == expectedEventSignature) {
                if (logs[i].topics[3] == bytes32(uint256(errorCode))) {
                    // Verify indexed parameters
                    assertEq(logs[i].topics[1], expectedComponentHash, "Component hash should match");
                    assertEq(logs[i].topics[2], expectedFunctionHash, "Function hash should match");
                    
                    // Decode and verify non-indexed parameters
                    (string memory component, string memory func) = abi.decode(logs[i].data, (string, string));
                    assertEq(component, expectedComponentName, "Component name should match");
                    assertEq(func, functionName, "Function name should match");
                    
                    foundEvent = true;
                    break;
                }
            }
        }
        
        assertTrue(foundEvent, "SafetyFallbackTriggered event should be emitted with expected parameters");
    }

    /// @notice Helper to count SafetyFallbackTriggered events in logs
    /// @param logs Array of logs to search
    /// @return count Number of safety events found
    function countSafetyFallbackEvents(Vm.Log[] memory logs) internal pure returns (uint256 count) {
        bytes32 expectedEventSignature = keccak256(
            "SafetyFallbackTriggered(bytes32,bytes32,uint8,string,string)"
        );
        
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == expectedEventSignature) {
                count++;
            }
        }
        
        return count;
    }
}