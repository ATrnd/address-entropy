// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console, Vm} from "forge-std/Test.sol";
import {AddressDataEntropy} from "../src/implementations/AddressDataEntropy.sol";
import {AddressDataEntropyTestProxy} from "./mock/AddressDataEntropyTestProxy.sol";

/**
 * @title Address Data Entropy Fallback Test
 * @notice Comprehensive tests for fallback mechanisms in AddressDataEntropy
 * @dev Uses minimal test proxy to force error conditions and test safety mechanisms
 */
contract AddressDataEntropyFallbackTest is Test {
    // Contracts
    AddressDataEntropy public addressEntropy;
    AddressDataEntropyTestProxy public proxy;

    // Common addresses
    address public owner;
    address public user;
    address public user2;

    // Seed addresses for the entropy contract
    address[3] public seedAddresses;

    // Component identifiers for fallback tracking
    uint8 internal constant COMPONENT_ADDRESS_EXTRACTION = 1;
    uint8 internal constant COMPONENT_SEGMENT_EXTRACTION = 2;
    uint8 internal constant COMPONENT_ENTROPY_GENERATION = 3;

    // Error code constants for verification
    uint8 internal constant ERROR_ZERO_ADDRESS = 1;
    uint8 internal constant ERROR_INSUFFICIENT_ADDRESS_DIVERSITY = 2;
    uint8 internal constant ERROR_ZERO_SEGMENT = 3;
    uint8 internal constant ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS = 4;
    uint8 internal constant ERROR_UPDATE_CYCLE_DISRUPTION = 5;

    // Function names for error reporting
    string internal constant FUNC_GET_ENTROPY = "getEntropy";
    string internal constant FUNC_EXTRACT_ADDRESS_SEGMENT = "extractAddressSegment";
    string internal constant FUNC_UPDATE_ENTROPY_STATE = "updateEntropyState";

    function setUp() public {
        // Setup addresses
        owner = makeAddr("owner");
        user = makeAddr("user");
        user2 = makeAddr("user2");

        // Fund users for tests
        vm.deal(user, 10 ether);
        vm.deal(user2, 10 ether);

        // Setup seed addresses for entropy
        seedAddresses[0] = makeAddr("seed1");
        seedAddresses[1] = makeAddr("seed2");
        seedAddresses[2] = makeAddr("seed3");

        // Deploy contracts
        vm.startPrank(owner);
        addressEntropy = new AddressDataEntropy(owner, seedAddresses);
        proxy = new AddressDataEntropyTestProxy(owner, seedAddresses);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                     PRIMARY FALLBACK PATH TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test the zero address fallback path in getEntropy
    function test_ZeroAddressInGetEntropy() public {
        // Setup
        proxy.resetState();

        // Inject zero address at current entropy address index to trigger zero address in getEntropy
        proxy.injectZeroAddressAtCurrentIndex();

        // Record initial component error count
        uint256 initialErrorCount = proxy.getEntropyGenerationZeroAddressCount();

        // Record logs to check for events
        vm.recordLogs();

        // Execute - call with different user to test msg.sender inclusion
        vm.prank(user);
        bytes32 entropy = proxy.getEntropy(123);

        // Verify entropy is non-zero
        assertTrue(entropy != bytes32(0), "Emergency entropy should be non-zero");

        // Verify component-specific error counter incremented
        assertEq(
            proxy.getEntropyGenerationZeroAddressCount(),
            initialErrorCount + 1,
            "Component-specific error counter should increment"
        );

        // Verify event emission
        Vm.Log[] memory entries = vm.getRecordedLogs();
        verifyFallbackEvent(
            entries,
            COMPONENT_ENTROPY_GENERATION,
            FUNC_GET_ENTROPY,
            ERROR_ZERO_ADDRESS
        );
    }

    /// @notice Test zero segment fallback path
    function test_ZeroSegmentInExtractAddressSegment() public {
        // Setup - ensure we force zero segment behavior
        proxy.resetState();
        proxy.forceSetZeroSegment(true);

        // Record initial component error count
        uint256 initialErrorCount = proxy.getSegmentExtractionZeroSegmentCount();

        // Record logs
        vm.recordLogs();

        // Call extractAddressSegment directly - this should trigger the zero segment check
        address testAddr = makeAddr("testAddress");
        bytes5 segment = proxy.callExtractAddressSegment(testAddr, 0);

        // Verify segment is non-zero (fallback segment)
        assertTrue(segment != bytes5(0), "Fallback segment should not be zero");

        // Verify component-specific error counter incremented
        assertEq(
            proxy.getSegmentExtractionZeroSegmentCount(),
            initialErrorCount + 1,
            "Component-specific error counter should increment"
        );

        // Verify event emission
        Vm.Log[] memory entries = vm.getRecordedLogs();
        verifyFallbackEvent(
            entries,
            COMPONENT_SEGMENT_EXTRACTION,
            FUNC_EXTRACT_ADDRESS_SEGMENT,
            ERROR_ZERO_SEGMENT
        );
    }

    /// @notice Test segment index out of bounds handling
    function test_SegmentIndexOutOfBounds() public {
        // Setup - force segment index out of bounds behavior
        proxy.resetState();
        proxy.forceSetInvalidSegmentIndex(true);

        // Record initial component error count
        uint256 initialErrorCount = proxy.getSegmentExtractionOutOfBoundsCount();

        // Record logs
        vm.recordLogs();

        // Execute - this should trigger the out-of-bounds handling
        address testAddr = makeAddr("testAddress");
        bytes5 segment = proxy.callExtractAddressSegment(testAddr, 0);

        // Verify segment is non-zero (fallback segment)
        assertTrue(segment != bytes5(0), "Should get non-zero fallback segment");

        // Verify component-specific error counter incremented
        assertEq(
            proxy.getSegmentExtractionOutOfBoundsCount(),
            initialErrorCount + 1,
            "Component-specific error counter should increment"
        );

        // Verify event emission
        Vm.Log[] memory entries = vm.getRecordedLogs();
        verifyFallbackEvent(
            entries,
            COMPONENT_SEGMENT_EXTRACTION,
            FUNC_EXTRACT_ADDRESS_SEGMENT,
            ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS
        );
    }

    /// @notice Test multiple fallback events during entropy generation
    function test_MultipleFallbackEvents() public {
        // Setup - force multiple conditions
        proxy.resetState();
        proxy.forceSetZeroAddress(true);

        // Record logs
        vm.recordLogs();

        // Execute
        vm.prank(user);
        proxy.getEntropy(123);

        // Get the logs
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Count fallback events
        uint fallbackEventCount = 0;
        bytes32 expectedEventSignature = keccak256(
            "SafetyFallbackTriggered(bytes32,bytes32,uint8,string,string)"
        );

        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == expectedEventSignature) {
                fallbackEventCount++;
            }
        }

        // Verify we have at least one fallback event
        assertTrue(fallbackEventCount > 0, "At least one fallback event should be emitted");
    }

    /// @notice Test the details of fallback events
    function test_FallbackEventDetails() public {
        // Setup
        proxy.resetState();

        // Record logs
        vm.recordLogs();

        // Generate custom fallback events with different error codes
        proxy.forceEmitCustomFallback(COMPONENT_ENTROPY_GENERATION, FUNC_GET_ENTROPY, ERROR_ZERO_ADDRESS);
        proxy.forceEmitCustomFallback(COMPONENT_SEGMENT_EXTRACTION, FUNC_EXTRACT_ADDRESS_SEGMENT, ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS);
        proxy.forceEmitCustomFallback(COMPONENT_ADDRESS_EXTRACTION, FUNC_UPDATE_ENTROPY_STATE, ERROR_ZERO_ADDRESS);

        // Get logs
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Map to track which error codes we've found
        bool[6] memory foundErrorCodes; // Index 0 unused, codes are 1-5

        // Verify each event
        bytes32 expectedEventSignature = keccak256(
            "SafetyFallbackTriggered(bytes32,bytes32,uint8,string,string)"
        );

        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == expectedEventSignature) {
                uint8 errorCode = uint8(uint256(entries[i].topics[3]));
                if (errorCode > 0 && errorCode <= 5) {
                    foundErrorCodes[errorCode] = true;
                }
            }
        }

        // Verify we found the error codes we emitted
        assertTrue(foundErrorCodes[ERROR_ZERO_ADDRESS], "ERROR_ZERO_ADDRESS event should be found");
        assertTrue(foundErrorCodes[ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS], "ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS event should be found");
    }

    /*//////////////////////////////////////////////////////////////
                      COMPONENT ERROR TRACKING TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test component error count getters
    function test_ComponentErrorCountGetters() public {
        // Setup
        proxy.resetState();

        // Check initial values
        assertEq(proxy.getAddressExtractionZeroAddressCount(), 0, "Initial zero address count should be 0");
        assertEq(proxy.getSegmentExtractionZeroSegmentCount(), 0, "Initial zero segment count should be 0");
        assertEq(proxy.getSegmentExtractionOutOfBoundsCount(), 0, "Initial out of bounds count should be 0");
        assertEq(proxy.getEntropyGenerationCycleDisruptionCount(), 0, "Initial cycle disruption count should be 0");

        // Increment specific error counters
        proxy.forceIncrementComponentErrorCount(COMPONENT_ADDRESS_EXTRACTION, ERROR_ZERO_ADDRESS);
        proxy.forceIncrementComponentErrorCount(COMPONENT_SEGMENT_EXTRACTION, ERROR_ZERO_SEGMENT);
        proxy.forceIncrementComponentErrorCount(COMPONENT_SEGMENT_EXTRACTION, ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS);
        proxy.forceIncrementComponentErrorCount(COMPONENT_ENTROPY_GENERATION, ERROR_UPDATE_CYCLE_DISRUPTION);

        // Check counts with convenience getters
        assertEq(proxy.getAddressExtractionZeroAddressCount(), 1, "Address extraction zero address count should be 1");
        assertEq(proxy.getSegmentExtractionZeroSegmentCount(), 1, "Segment extraction zero segment count should be 1");
        assertEq(proxy.getSegmentExtractionOutOfBoundsCount(), 1, "Segment extraction out of bounds count should be 1");
        assertEq(proxy.getEntropyGenerationCycleDisruptionCount(), 1, "Entropy generation cycle disruption count should be 1");
    }

    /*//////////////////////////////////////////////////////////////
                      FALLBACK INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test extracting from an address with zero segment
    function test_ExtractAddressSegmentWithZeroSegment() public {
        // Setup - force zero segment behavior
        proxy.resetState();
        proxy.forceSetZeroSegment(true);
        address testAddr = makeAddr("testAddress");

        // Record logs
        vm.recordLogs();

        // Call extractAddressSegment - should trigger zero segment fallback
        bytes5 segment = proxy.callExtractAddressSegment(testAddr, 0);

        // Verify segment is non-zero (fallback)
        assertTrue(segment != bytes5(0), "Fallback segment should not be zero");

        // Verify event emission
        Vm.Log[] memory entries = vm.getRecordedLogs();
        verifyFallbackEvent(
            entries,
            COMPONENT_SEGMENT_EXTRACTION,
            FUNC_EXTRACT_ADDRESS_SEGMENT,
            ERROR_ZERO_SEGMENT
        );
    }

    /// @notice Test cascading fallbacks when multiple error conditions are triggered
    function test_CascadingFallbacks() public {
        // Setup - force multiple fallback conditions
        proxy.resetState();
        proxy.forceSetZeroAddress(true);
        proxy.forceSetZeroSegment(true);
        proxy.forceSetInvalidSegmentIndex(true);

        // Record logs
        vm.recordLogs();

        // Call getEntropy - should trigger fallbacks
        vm.prank(user);
        bytes32 entropy = proxy.getEntropy(123);

        // Verify entropy is non-zero despite all the errors
        assertTrue(entropy != bytes32(0), "Entropy should be non-zero despite cascading fallbacks");

        // Get logs and count fallback events
        Vm.Log[] memory entries = vm.getRecordedLogs();
        uint fallbackEventCount = 0;
        bytes32 expectedEventSignature = keccak256(
            "SafetyFallbackTriggered(bytes32,bytes32,uint8,string,string)"
        );

        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == expectedEventSignature) {
                fallbackEventCount++;
            }
        }

        // Should have at least one fallback event
        assertTrue(fallbackEventCount > 0, "At least one fallback event should be emitted");
    }

    /// @notice Test direct component error tracking functions work correctly
    function test_ComponentErrorTracking() public {
        // Initial state - no errors
        assertFalse(proxy.hasComponentErrors(COMPONENT_ADDRESS_EXTRACTION), "Should have no errors initially");
        assertFalse(proxy.hasComponentErrors(COMPONENT_SEGMENT_EXTRACTION), "Should have no errors initially");
        assertFalse(proxy.hasComponentErrors(COMPONENT_ENTROPY_GENERATION), "Should have no errors initially");

        // Force some errors
        proxy.forceIncrementComponentErrorCount(COMPONENT_ADDRESS_EXTRACTION, ERROR_ZERO_ADDRESS);
        proxy.forceIncrementComponentErrorCount(COMPONENT_SEGMENT_EXTRACTION, ERROR_ZERO_SEGMENT);

        // Check component has errors
        assertTrue(proxy.hasComponentErrors(COMPONENT_ADDRESS_EXTRACTION), "Should have errors after increment");
        assertTrue(proxy.hasComponentErrors(COMPONENT_SEGMENT_EXTRACTION), "Should have errors after increment");
        assertFalse(proxy.hasComponentErrors(COMPONENT_ENTROPY_GENERATION), "Should still have no errors");

        // Check total error counts
        assertEq(proxy.getComponentTotalErrorCount(COMPONENT_ADDRESS_EXTRACTION), 1, "Total should be 1");
        assertEq(proxy.getComponentTotalErrorCount(COMPONENT_SEGMENT_EXTRACTION), 1, "Total should be 1");
        assertEq(proxy.getComponentTotalErrorCount(COMPONENT_ENTROPY_GENERATION), 0, "Total should be 0");
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Helper to verify fallback events with correct parameters
    /// @param logs Array of logs to search for events
    /// @param componentId Expected component ID in the event
    /// @param expectedFunction Expected function name in the event
    /// @param expectedErrorCode Expected error code in the event
    function verifyFallbackEvent(
        Vm.Log[] memory logs,
        uint8 componentId,
        string memory expectedFunction,
        uint8 expectedErrorCode
    ) internal view {
        bool foundEvent = false;
        bytes32 expectedEventSignature = keccak256(
            "SafetyFallbackTriggered(bytes32,bytes32,uint8,string,string)"
        );

        // Get the expected component name based on component ID
        string memory expectedComponentName = proxy.exposedGetComponentName(componentId);
        bytes32 expectedComponentHash = keccak256(bytes(expectedComponentName));
        bytes32 expectedFunctionHash = keccak256(bytes(expectedFunction));

        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == expectedEventSignature) {
                // Check if this event matches our expected parameters
                if (logs[i].topics[3] == bytes32(uint256(expectedErrorCode))) {
                    foundEvent = true;

                    // Verify indexed parameters
                    assertEq(logs[i].topics[1], expectedComponentHash, "Component hash should match");
                    assertEq(logs[i].topics[2], expectedFunctionHash, "Function hash should match");
                    assertEq(uint8(uint256(logs[i].topics[3])), expectedErrorCode, "Error code should match");

                    // Decode and verify non-indexed parameters
                    (string memory component, string memory functionName) = abi.decode(logs[i].data, (string, string));
                    assertEq(component, expectedComponentName, "Component name should match");
                    assertEq(functionName, expectedFunction, "Function name should match");

                    break;
                }
            }
        }

        assertTrue(foundEvent, "SafetyFallbackTriggered event should be emitted with expected parameters");
    }
}
