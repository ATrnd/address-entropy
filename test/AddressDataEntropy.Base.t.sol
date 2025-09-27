// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console, Vm} from "forge-std/Test.sol";
import {AddressDataEntropy} from "../src/implementations/AddressDataEntropy.sol";
import {AddressDataEntropyTestProxy} from "./mock/AddressDataEntropyTestProxy.sol";
import {IAddressEntropy} from "../src/interfaces/IAddressEntropy.sol";

/**
 * @title Address Data Entropy Base Test
 * @notice Basic tests for the AddressDataEntropy contract without mocks
 * @dev Tests core functionality, constructor setup, and basic operations using direct contract
 */
contract AddressDataEntropyBaseTest is Test {
    // Contract under test - using proxy for state inspection functions
    AddressDataEntropyTestProxy public addressEntropy;

    // Common addresses
    address public owner;
    address public user;
    address public user2;
    address public user3;

    // Seed addresses for the entropy contract
    address[3] public seedAddresses;

    // Component identifiers for fallback tracking (from constants)
    uint8 internal constant COMPONENT_ADDRESS_EXTRACTION = 1;
    uint8 internal constant COMPONENT_SEGMENT_EXTRACTION = 2;
    uint8 internal constant COMPONENT_ENTROPY_GENERATION = 3;

    // Error code constants for verification
    uint8 internal constant ERROR_ZERO_ADDRESS = 1;
    uint8 internal constant ERROR_ZERO_SEGMENT = 2;
    uint8 internal constant ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS = 3;
    uint8 internal constant ERROR_UPDATE_CYCLE_DISRUPTION = 4;

    function setUp() public {
        // Setup addresses
        owner = makeAddr("owner");
        user = makeAddr("user");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Fund users for tests
        vm.deal(user, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);

        // Setup seed addresses for entropy
        seedAddresses[0] = makeAddr("seed1");
        seedAddresses[1] = makeAddr("seed2");
        seedAddresses[2] = makeAddr("seed3");

        // Deploy contract - using test proxy for state inspection functions
        vm.startPrank(owner);
        addressEntropy = new AddressDataEntropyTestProxy(owner, seedAddresses);

        // Configure user as the orchestrator to allow getEntropy calls in tests
        addressEntropy.setOrchestratorOnce(user);
        vm.stopPrank();
    }

    /// ============================================
    /// ============= Constructor Tests ===========
    /// ============================================

    function test_ConstructorSetup() public view {
        // Verify initial state variables are set correctly
        (uint256 addressIndex, uint256 segmentIndex, uint256 updatePosition) = addressEntropy.getCurrentIndices();
        assertEq(addressIndex, 0, "Initial address index should be 0");
        assertEq(segmentIndex, 0, "Initial segment index should be 0");
        assertEq(updatePosition, 0, "Initial update position should be 0");

        // Verify transaction counter is 0
        assertEq(addressEntropy.getTransactionCounter(), 0, "Initial transaction counter should be 0");

        // Verify seed addresses were set correctly
        address[3] memory entropyAddresses = addressEntropy.getAllEntropyAddresses();
        for (uint256 i = 0; i < 3; i++) {
            assertEq(entropyAddresses[i], seedAddresses[i], "Seed address should match");
        }
    }

    function test_RevertWhen_ConstructorWithZeroAddress() public {
        // Create seed addresses with a zero address
        address[3] memory badSeeds;
        badSeeds[0] = makeAddr("seed1");
        badSeeds[1] = address(0); // Zero address should cause revert
        badSeeds[2] = makeAddr("seed3");

        // Expect the revert with AddressEntropy__InvalidArraySize
        vm.expectRevert();
        new AddressDataEntropy(owner, badSeeds);
    }

    function test_OwnershipSetup() public view {
        assertEq(addressEntropy.owner(), owner, "Owner should be set correctly");
    }

    /// ============================================
    /// ============= Basic Entropy Tests =========
    /// ============================================

    function test_FirstEntropyCall() public {
        vm.prank(user);
        uint256 salt = 123;
        bytes32 entropy = addressEntropy.getEntropy(salt, user);

        // Since entropy is non-deterministic, we just verify it's not zero
        assertTrue(entropy != bytes32(0), "Entropy should not be zero");

        // Check state changes
        assertEq(addressEntropy.getTransactionCounter(), 1, "Transaction counter should increment");

        // Get current indices after call
        (uint256 addressIndex, uint256 segmentIndex, ) = addressEntropy.getCurrentIndices();
        assertEq(addressIndex, 1, "Address index should increment");
        assertEq(segmentIndex, 1, "Segment index should increment");
    }

    function test_MultipleEntropyCalls() public {
        vm.startPrank(user);
        uint256 salt = 123;

        // First call
        bytes32 entropy1 = addressEntropy.getEntropy(salt, user);

        // Second call
        bytes32 entropy2 = addressEntropy.getEntropy(salt, user);

        // Entropy should be different even with the same salt
        assertTrue(entropy1 != entropy2, "Entropy values should be different even with same salt");

        // Check state changes
        assertEq(addressEntropy.getTransactionCounter(), 2, "Transaction counter should increment twice");

        // Get current indices after calls
        (uint256 addressIndex, uint256 segmentIndex, ) = addressEntropy.getCurrentIndices();
        assertEq(addressIndex, 2, "Address index should increment twice");
        assertEq(segmentIndex, 2, "Segment index should increment twice");

        vm.stopPrank();
    }

    function test_DifferentSaltValues() public {
        vm.startPrank(user);

        // Generate entropy with different salts
        bytes32 entropy1 = addressEntropy.getEntropy(123, user);
        bytes32 entropy2 = addressEntropy.getEntropy(456, user);

        // Entropy should be different with different salts
        assertTrue(entropy1 != entropy2, "Entropy should be different with different salts");

        vm.stopPrank();
    }

    function test_DifferentCallers() public {
        // With access control + address passing, test different actualCaller addresses
        vm.prank(user); // user = orchestrator
        bytes32 entropy1 = addressEntropy.getEntropy(123, user);

        vm.prank(user); // user = orchestrator, but different actualCaller
        bytes32 entropy2 = addressEntropy.getEntropy(123, user2);

        // Entropy should be different with sequential calls even with same salt
        assertTrue(entropy1 != entropy2, "Sequential entropy calls should produce different values");
    }

    /// @notice Test address diversity restoration - multiple different addresses can be used
    function test_AddressDiversityRestored() public {
        uint256 baseSalt = 500;
        address[] memory testAddresses = new address[](5);
        bytes32[] memory entropies = new bytes32[](5);

        // Create diverse test addresses
        testAddresses[0] = makeAddr("diverseAddr1");
        testAddresses[1] = makeAddr("diverseAddr2");
        testAddresses[2] = makeAddr("diverseAddr3");
        testAddresses[3] = makeAddr("diverseAddr4");
        testAddresses[4] = makeAddr("diverseAddr5");

        // Generate entropy using diverse actualCaller addresses (all authorized by orchestrator)
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(user); // Orchestrator authorizes
            entropies[i] = addressEntropy.getEntropy(baseSalt, testAddresses[i]);
        }

        // Verify all entropies are different (address diversity working)
        for (uint256 i = 0; i < 5; i++) {
            for (uint256 j = i + 1; j < 5; j++) {
                assertTrue(
                    entropies[i] != entropies[j],
                    string(abi.encodePacked("Entropy ", vm.toString(i), " and ", vm.toString(j), " should differ"))
                );
            }
        }
    }

    /// @notice Test actualCaller parameter validation
    function test_ActualCallerValidation() public {
        uint256 salt = 999;

        // Test that zero address actualCaller is rejected
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(IAddressEntropy.AddressEntropy__InvalidOrchestratorAddress.selector));
        addressEntropy.getEntropy(salt, address(0));

        // Test that valid actualCaller works
        vm.prank(user);
        bytes32 entropy = addressEntropy.getEntropy(salt, makeAddr("validAddr"));
        assertTrue(entropy != bytes32(0), "Valid actualCaller should work");
    }

    /// ============================================
    /// ============= State Update Tests ==========
    /// ============================================

    function test_AddressIndexCycling() public {
        // Get initial indices
        (uint256 initialAddrIndex, , ) = addressEntropy.getCurrentIndices();

        // Call getEntropy multiple times to cycle through address indices
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(user);
            addressEntropy.getEntropy(i, user);

            // Check address index cycling
            (uint256 addrIndex, , ) = addressEntropy.getCurrentIndices();
            assertEq(addrIndex, (initialAddrIndex + i + 1) % 3, "Address index should cycle correctly");
        }
    }

    function test_SegmentIndexCycling() public {
        // Get initial indices
        ( , uint256 initialSegIndex, ) = addressEntropy.getCurrentIndices();

        // Call getEntropy multiple times to cycle through segment indices
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(user);
            addressEntropy.getEntropy(i, user);

            // Check segment index cycling
            (, uint256 segIndex, ) = addressEntropy.getCurrentIndices();
            assertEq(segIndex, (initialSegIndex + i + 1) % 4, "Segment index should cycle correctly");
        }
    }

    function test_UpdatePositionWithNewAddress() public {
        // Get initial indices
        (, , uint256 initialUpdatePos) = addressEntropy.getCurrentIndices();

        // Call with orchestrator - should update the address array
        vm.prank(user);
        addressEntropy.getEntropy(123, user);

        // Get new indices
        (, , uint256 newUpdatePos) = addressEntropy.getCurrentIndices();

        // Update position should advance by 1 when an address is added
        uint256 expectedUpdatePos = (initialUpdatePos + 1) % 3; // 3 is ADDRESS_ARRAY_SIZE
        assertEq(newUpdatePos, expectedUpdatePos, "Update position should advance when address is added");
    }

    function test_UpdatePositionWithExistingAddress() public {
        // First, make sure this user is in the array by calling once
        vm.prank(user);
        addressEntropy.getEntropy(123, user);

        // Get indices after first call
        (, , uint256 initialUpdatePos) = addressEntropy.getCurrentIndices();

        // Call again with the same user
        vm.prank(user);
        addressEntropy.getEntropy(456, user);

        // Get indices after second call
        (, , uint256 newUpdatePos) = addressEntropy.getCurrentIndices();

        // Update position should remain the same since the address was already in the array
        assertEq(newUpdatePos, initialUpdatePos, "Update position should not change when using existing address");
    }

    /// ============================================
    /// ============= Address Update Tests ========
    /// ============================================

    function test_EntropyAddressUpdate() public {
        // Get initial addresses
        address[3] memory initialAddresses = addressEntropy.getAllEntropyAddresses();

        // Call with the orchestrator to trigger address update
        vm.prank(user);
        addressEntropy.getEntropy(123, user);

        // Get new addresses
        address[3] memory newAddresses = addressEntropy.getAllEntropyAddresses();

        // The address at update position should now be the user (orchestrator)
        bool addressUpdated = false;
        for (uint256 i = 0; i < 3; i++) {
            if (newAddresses[i] == user) {
                addressUpdated = true;
                break;
            }
        }

        assertTrue(addressUpdated, "User (orchestrator) address should be added to the array");

        // Only one address should have changed
        uint256 changedCount = 0;
        for (uint256 i = 0; i < 3; i++) {
            if (initialAddresses[i] != newAddresses[i]) {
                changedCount++;
            }
        }
        assertEq(changedCount, 1, "Exactly one address should be updated");
    }

    function test_NoEntropyAddressUpdateWithExistingAddress() public {
        // First, add the orchestrator address to the array
        vm.prank(user);
        addressEntropy.getEntropy(123, user);

        // Record the state of the array after first call
        address[3] memory initialAddresses = addressEntropy.getAllEntropyAddresses();

        // Call again with the same orchestrator
        vm.prank(user);
        addressEntropy.getEntropy(456, user);

        // Get new addresses
        address[3] memory newAddresses = addressEntropy.getAllEntropyAddresses();

        // Array should be unchanged
        for (uint256 i = 0; i < 3; i++) {
            assertEq(initialAddresses[i], newAddresses[i], "Address array should remain unchanged");
        }
    }

    /// ============================================
    /// ======== Transaction Counter Tests ========
    /// ============================================

    function test_TransactionCounterIncrement() public {
        // Get initial transaction counter
        uint256 initialCounter = addressEntropy.getTransactionCounter();

        // Call getEntropy once
        vm.prank(user);
        addressEntropy.getEntropy(123, user);

        // Check counter incremented by 1
        assertEq(
            addressEntropy.getTransactionCounter(),
            initialCounter + 1,
            "Transaction counter should increment by 1"
        );

        // Call getEntropy again
        vm.prank(user);
        addressEntropy.getEntropy(456, user);

        // Check counter incremented by 1 again
        assertEq(
            addressEntropy.getTransactionCounter(),
            initialCounter + 2,
            "Transaction counter should increment by 1 again"
        );
    }

    function test_TransactionCounterWithMultipleUsers() public {
        // NOTE: With access control, only the orchestrator can call getEntropy
        // This test now verifies multiple calls from the same orchestrator
        uint256 initialCounter = addressEntropy.getTransactionCounter();

        // Call getEntropy with orchestrator (user)
        vm.prank(user);
        addressEntropy.getEntropy(123, user);

        // Check counter incremented by 1
        assertEq(
            addressEntropy.getTransactionCounter(),
            initialCounter + 1,
            "Transaction counter should increment by 1 with first call"
        );

        // Call getEntropy again with orchestrator
        vm.prank(user);
        addressEntropy.getEntropy(456, user);

        // Check counter incremented by 1 again
        assertEq(
            addressEntropy.getTransactionCounter(),
            initialCounter + 2,
            "Transaction counter should increment by 1 with second call"
        );
    }

    /// ============================================
    /// ========= Event Emission Tests ============
    /// ============================================

    function test_EntropyGeneratedEvent() public {
        // Record logs
        vm.recordLogs();

        // Call getEntropy
        vm.prank(user);
        addressEntropy.getEntropy(123, user);

        // Get emitted logs
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Check for EntropyGenerated event
        bool foundEvent = false;
        bytes32 expectedEventSignature = keccak256(
            "EntropyGenerated(address,address,uint256,uint256)"
        );

        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == expectedEventSignature) {
                // Check indexed parameters
                address eventRequester = address(uint160(uint256(entries[i].topics[1])));
                address eventActualCaller = address(uint160(uint256(entries[i].topics[2])));
                assertEq(eventRequester, user, "Event requester should be the orchestrator");
                assertEq(eventActualCaller, user, "Event actualCaller should match provided actualCaller");

                // Decode non-indexed parameters
                (uint256 segmentIndex, uint256 blockNumber) = abi.decode(entries[i].data, (uint256, uint256));
                assertEq(segmentIndex, 0, "Segment index should match initial value");
                assertEq(blockNumber, block.number, "Block number should match current block");

                foundEvent = true;
                break;
            }
        }

        assertTrue(foundEvent, "EntropyGenerated event should be emitted");
    }

    function test_EntropyAddressUpdatedEvent() public {
        // Record logs
        vm.recordLogs();

        // Call with orchestrator to trigger address update
        vm.prank(user);
        addressEntropy.getEntropy(123, user);

        // Get emitted logs
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Check for EntropyAddressUpdated event
        bool foundEvent = false;
        bytes32 expectedEventSignature = keccak256(
            "EntropyAddressUpdated(uint256,address,address)"
        );

        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == expectedEventSignature) {
                // Check indexed parameters
                uint256 position = uint256(entries[i].topics[1]);
                assertTrue(position < 3, "Position should be within array bounds");

                // Decode non-indexed parameters
                (address oldAddress, address newAddress) = abi.decode(entries[i].data, (address, address));
                assertEq(newAddress, user, "New address should match the orchestrator");
                assertTrue(oldAddress != address(0), "Old address should not be zero");

                foundEvent = true;
                break;
            }
        }

        assertTrue(foundEvent, "EntropyAddressUpdated event should be emitted");
    }

    /// ============================================
    /// ======== Error Counter Tests ==============
    /// ============================================

    function test_InitialErrorCountsAreZero() public view {
        // Check counts for each component and error
        for (uint8 componentId = 1; componentId <= 3; componentId++) {
            for (uint8 errorCode = 1; errorCode <= 5; errorCode++) {
                assertEq(
                    addressEntropy.getComponentErrorCount(componentId, errorCode),
                    0,
                    "Initial error count should be zero"
                );
            }
        }

        // Check component total counts
        for (uint8 componentId = 1; componentId <= 3; componentId++) {
            assertEq(
                addressEntropy.getComponentTotalErrorCount(componentId),
                0,
                "Initial total error count should be zero"
            );
        }

        // Check individual error count functions
        assertEq(addressEntropy.getAddressExtractionZeroAddressCount(), 0, "Should have no zero address errors initially");
        assertEq(addressEntropy.getSegmentExtractionZeroSegmentCount(), 0, "Should have no zero segment errors initially");
        assertEq(addressEntropy.getSegmentExtractionOutOfBoundsCount(), 0, "Should have no out of bounds errors initially");
        assertEq(addressEntropy.getEntropyGenerationCycleDisruptionCount(), 0, "Should have no cycle disruption errors initially");
        assertEq(addressEntropy.getEntropyGenerationZeroSegmentCount(), 0, "Should have no entropy zero segment errors initially");
    }

    function test_SpecificErrorCounterGetters() public view {
        // Check specific getters return zero initially
        assertEq(
            addressEntropy.getAddressExtractionZeroAddressCount(),
            0,
            "Address extraction zero address count should be 0 initially"
        );

        assertEq(
            addressEntropy.getSegmentExtractionZeroSegmentCount(),
            0,
            "Segment extraction zero segment count should be 0 initially"
        );

        assertEq(
            addressEntropy.getSegmentExtractionOutOfBoundsCount(),
            0,
            "Segment extraction out of bounds count should be 0 initially"
        );

        assertEq(
            addressEntropy.getEntropyGenerationCycleDisruptionCount(),
            0,
            "Entropy generation cycle disruption count should be 0 initially"
        );

        assertEq(
            addressEntropy.getEntropyGenerationZeroAddressCount(),
            0,
            "Entropy generation zero address count should be 0 initially"
        );

        assertEq(
            addressEntropy.getEntropyGenerationZeroSegmentCount(),
            0,
            "Entropy generation zero segment count should be 0 initially"
        );
    }

    /// ============================================
    /// ======== Basic Segment Tests ==============
    /// ============================================

    function test_GetAddressSegments() public {
        // Create a forge-generated address for testing
        address testAddr = makeAddr("segmentTestAddress");

        // Get all segments from this address
        bytes5[4] memory segments = addressEntropy.getAddressSegments(testAddr);

        // Convert address to uint160 for manual extraction
        uint160 addrValue = uint160(testAddr);

        // Manually extract each segment for comparison
        bytes5 expectedSegment0 = bytes5(uint40(addrValue & 0xFFFFFFFFFF));
        bytes5 expectedSegment1 = bytes5(uint40((addrValue >> 40) & 0xFFFFFFFFFF));
        bytes5 expectedSegment2 = bytes5(uint40((addrValue >> 80) & 0xFFFFFFFFFF));
        bytes5 expectedSegment3 = bytes5(uint40((addrValue >> 120) & 0xFFFFFFFFFF));

        // Verify the segments match our manual extraction
        assertEq(segments[0], expectedSegment0, "Segment 0 should match expected value");
        assertEq(segments[1], expectedSegment1, "Segment 1 should match expected value");
        assertEq(segments[2], expectedSegment2, "Segment 2 should match expected value");
        assertEq(segments[3], expectedSegment3, "Segment 3 should match expected value");

        // Additional test to ensure segments are unique (for most addresses)
        assertTrue(segments[0] != segments[1] || segments[1] != segments[2] || segments[2] != segments[3],
            "At least some segments should be different from each other");
    }

    function test_GetAddressSegmentsForZeroAddress() public view {
        // Get segments for zero address
        bytes5[4] memory segments = addressEntropy.getAddressSegments(address(0));

        // All segments should be non-zero (fallback segments)
        for (uint256 i = 0; i < 4; i++) {
            assertTrue(segments[i] != bytes5(0), "Fallback segment should not be zero");
        }
    }

    function test_ExtractAllSegments() public {
        // Create a test address
        address testAddr = makeAddr("allSegmentsTest");

        // Extract all segments
        bytes5[4] memory segments = addressEntropy.extractAllSegments(testAddr);

        // All segments should be non-zero
        for (uint256 i = 0; i < 4; i++) {
            assertTrue(segments[i] != bytes5(0), "Segment should not be zero");
        }

        // Verify against manual extraction
        uint160 addrValue = uint160(testAddr);

        bytes5 expectedSegment0 = bytes5(uint40(addrValue & 0xFFFFFFFFFF));
        bytes5 expectedSegment1 = bytes5(uint40((addrValue >> 40) & 0xFFFFFFFFFF));
        bytes5 expectedSegment2 = bytes5(uint40((addrValue >> 80) & 0xFFFFFFFFFF));
        bytes5 expectedSegment3 = bytes5(uint40((addrValue >> 120) & 0xFFFFFFFFFF));

        assertEq(segments[0], expectedSegment0, "Segment 0 should match expected value");
        assertEq(segments[1], expectedSegment1, "Segment 1 should match expected value");
        assertEq(segments[2], expectedSegment2, "Segment 2 should match expected value");
        assertEq(segments[3], expectedSegment3, "Segment 3 should match expected value");
    }
}
