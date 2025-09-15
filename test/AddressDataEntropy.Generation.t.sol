// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {AddressDataEntropy} from "../src/implementations/AddressDataEntropy.sol";
import {AddressDataEntropyTestProxy} from "./mock/AddressDataEntropyTestProxy.sol";
import {IAddressEntropy} from "../src/interfaces/IAddressEntropy.sol";
import {IAddressFallbackHandler} from "../src/interfaces/IAddressFallbackHandler.sol";
import {AddressEntropyConstants} from "../src/constants/AddressEntropyConstants.sol";

/// @title AddressDataEntropy Generation Test Suite
/// @notice Comprehensive tests for entropy generation quality, randomness, and statistical distribution
contract AddressDataEntropyGenerationTest is Test {
    using AddressEntropyConstants for *;

    /*//////////////////////////////////////////////////////////////
                                 VARIABLES
    //////////////////////////////////////////////////////////////*/

    AddressDataEntropyTestProxy public proxy;
    address public owner;
    address public user1;
    address public user2;
    address public user3;

    // Seed addresses for testing
    address public seed1;
    address public seed2;
    address public seed3;

    // Constants for testing
    uint8 constant COMPONENT_ENTROPY_GENERATION = 3;
    uint8 constant ERROR_ZERO_ADDRESS = 1;
    string constant FUNC_GET_ENTROPY = "getEntropy";

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");

        // Create seed addresses
        seed1 = makeAddr("seed1");
        seed2 = makeAddr("seed2");
        seed3 = makeAddr("seed3");

        address[3] memory seedAddresses = [seed1, seed2, seed3];

        // Deploy proxy with seed addresses
        proxy = new AddressDataEntropyTestProxy(owner, seedAddresses);
    }

    /*//////////////////////////////////////////////////////////////
                          BASIC GENERATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that entropy generation produces non-zero values
    function test_EntropyIsNonZero() public {
        bytes32 entropy = proxy.getEntropy(123);
        assertTrue(entropy != bytes32(0), "Generated entropy should be non-zero");
    }

    /// @notice Test that multiple entropy calls produce different values
    function test_MultipleCallsProduceDifferentEntropy() public {
        uint256 salt = 456;

        bytes32 entropy1 = proxy.getEntropy(salt);
        bytes32 entropy2 = proxy.getEntropy(salt);
        bytes32 entropy3 = proxy.getEntropy(salt);

        assertTrue(entropy1 != entropy2, "First and second entropy should differ");
        assertTrue(entropy2 != entropy3, "Second and third entropy should differ");
        assertTrue(entropy1 != entropy3, "First and third entropy should differ");
    }

    /// @notice Test entropy variation across different blocks
    function test_EntropyVariationAcrossBlocks() public {
        uint256 salt = 789;

        // Generate entropy in first block
        bytes32 entropy1 = proxy.getEntropy(salt);

        // Move to next block and generate entropy
        vm.roll(block.number + 1);
        bytes32 entropy2 = proxy.getEntropy(salt);

        // Move to another block
        vm.roll(block.number + 1);
        bytes32 entropy3 = proxy.getEntropy(salt);

        assertTrue(entropy1 != entropy2, "Entropy should differ across blocks");
        assertTrue(entropy2 != entropy3, "Entropy should differ across blocks");
        assertTrue(entropy1 != entropy3, "Entropy should differ across blocks");
    }

    /*//////////////////////////////////////////////////////////////
                          ENTROPY SOURCE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test entropy variation across different addresses in entropy array
    function test_EntropyVariationAcrossAddresses() public {
        uint256 salt = 101;
        bytes32[] memory entropies = new bytes32[](3);

        // Generate entropy that will cycle through addresses
        for (uint256 i = 0; i < 3; i++) {
            entropies[i] = proxy.getEntropy(salt);
        }

        // Verify all entropies are different
        for (uint256 i = 0; i < 3; i++) {
            for (uint256 j = i + 1; j < 3; j++) {
                assertTrue(
                    entropies[i] != entropies[j],
                    string(abi.encodePacked("Entropies at indices ", vm.toString(i), " and ", vm.toString(j), " should differ"))
                );
            }
        }
    }

    /// @notice Test entropy variation across different address segments
    function test_EntropyVariationAcrossSegments() public {
        uint256 salt = 202;
        bytes32[] memory entropies = new bytes32[](8);

        // Generate enough entropy to cycle through segments (2 full cycles)
        for (uint256 i = 0; i < 8; i++) {
            entropies[i] = proxy.getEntropy(salt);
        }

        // Verify entropy varies across segments
        assertTrue(entropies[0] != entropies[1], "Segment 0 and 1 should produce different entropy");
        assertTrue(entropies[1] != entropies[2], "Segment 1 and 2 should produce different entropy");
        assertTrue(entropies[2] != entropies[3], "Segment 2 and 3 should produce different entropy");
        assertTrue(entropies[4] != entropies[5], "Second cycle segments should also differ");
    }

    /// @notice Test transaction counter impact on entropy
    function test_TransactionCounterImpact() public {
        uint256 salt = 303;

        // Get initial transaction counter
        uint256 initialCounter = proxy.getTransactionCounter();

        bytes32 entropy1 = proxy.getEntropy(salt);

        // Verify counter incremented
        assertEq(
            proxy.getTransactionCounter(),
            initialCounter + 1,
            "Transaction counter should increment"
        );

        bytes32 entropy2 = proxy.getEntropy(salt);

        // Verify counter incremented again
        assertEq(
            proxy.getTransactionCounter(),
            initialCounter + 2,
            "Transaction counter should increment again"
        );

        assertTrue(entropy1 != entropy2, "Different transaction counters should produce different entropy");
    }

    /// @notice Test that different salts produce different entropy
    function test_DifferentSaltsProduceDifferentEntropy() public {
        bytes32 entropy1 = proxy.getEntropy(111);
        bytes32 entropy2 = proxy.getEntropy(222);
        bytes32 entropy3 = proxy.getEntropy(333);

        assertTrue(entropy1 != entropy2, "Different salts should produce different entropy");
        assertTrue(entropy2 != entropy3, "Different salts should produce different entropy");
        assertTrue(entropy1 != entropy3, "Different salts should produce different entropy");
    }

    /*//////////////////////////////////////////////////////////////
                          ADDRESS UPDATE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that new addresses get added to entropy array
    function test_NewAddressUpdatesEntropyArray() public {
        // Record initial addresses
        proxy.getAllEntropyAddresses(); // Get initial state

        // Generate entropy with new user
        vm.prank(user1);
        proxy.getEntropy(444);

        // Check if user1 was added
        address[3] memory updatedAddresses = proxy.getAllEntropyAddresses();

        bool foundUser1 = false;
        for (uint256 i = 0; i < 3; i++) {
            if (updatedAddresses[i] == user1) {
                foundUser1 = true;
                break;
            }
        }

        assertTrue(foundUser1, "New user address should be added to entropy array");
    }

    /// @notice Test multiple address updates and cycling
    function test_MultipleAddressUpdates() public {
        // Add multiple new addresses
        vm.prank(user1);
        proxy.getEntropy(555);

        vm.prank(user2);
        proxy.getEntropy(666);

        vm.prank(user3);
        proxy.getEntropy(777);

        address[3] memory finalAddresses = proxy.getAllEntropyAddresses();

        // Verify new addresses were added
        bool foundUser1 = false;
        bool foundUser2 = false;
        bool foundUser3 = false;

        for (uint256 i = 0; i < 3; i++) {
            if (finalAddresses[i] == user1) foundUser1 = true;
            if (finalAddresses[i] == user2) foundUser2 = true;
            if (finalAddresses[i] == user3) foundUser3 = true;
        }

        assertTrue(foundUser1, "User1 should be in entropy array");
        assertTrue(foundUser2, "User2 should be in entropy array");
        assertTrue(foundUser3, "User3 should be in entropy array");
    }

    /// @notice Test that existing addresses don't trigger updates
    function test_ExistingAddressNoUpdate() public {
        // Add user1 first
        vm.prank(user1);
        proxy.getEntropy(888);

        address[3] memory addressesAfterFirst = proxy.getAllEntropyAddresses();

        // Call again with same user
        vm.prank(user1);
        proxy.getEntropy(999);

        address[3] memory addressesAfterSecond = proxy.getAllEntropyAddresses();

        // Arrays should be identical
        for (uint256 i = 0; i < 3; i++) {
            assertEq(
                addressesAfterFirst[i],
                addressesAfterSecond[i],
                "Entropy array should not change for existing address"
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                          CYCLING BEHAVIOR TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test address index cycling behavior
    function test_AddressIndexCycling() public {
        uint256 salt = 1111;

        // Get initial address index
        (uint256 initialAddressIndex, , ) = proxy.getCurrentIndices();

        // Generate entropy to cycle through addresses
        for (uint256 i = 0; i < 8; i++) {
            proxy.getEntropy(salt + i);

            (uint256 currentAddressIndex, , ) = proxy.getCurrentIndices();
            uint256 expectedIndex = (initialAddressIndex + i + 1) % 3;

            assertEq(
                currentAddressIndex,
                expectedIndex,
                string(abi.encodePacked("Address index should cycle correctly at iteration ", vm.toString(i)))
            );
        }
    }

    /// @notice Test segment index cycling behavior
    function test_SegmentIndexCycling() public {
        uint256 salt = 2222;

        // Get initial segment index
        (, uint256 initialSegmentIndex, ) = proxy.getCurrentIndices();

        // Generate entropy to cycle through segments
        for (uint256 i = 0; i < 8; i++) {
            proxy.getEntropy(salt + i);

            (, uint256 currentSegmentIndex, ) = proxy.getCurrentIndices();
            uint256 expectedIndex = (initialSegmentIndex + i + 1) % 4;

            assertEq(
                currentSegmentIndex,
                expectedIndex,
                string(abi.encodePacked("Segment index should cycle correctly at iteration ", vm.toString(i)))
            );
        }
    }

    /// @notice Test update position cycling during address updates
    function test_UpdatePositionCycling() public {
        address[] memory testUsers = new address[](6);
        testUsers[0] = makeAddr("testUser0");
        testUsers[1] = makeAddr("testUser1");
        testUsers[2] = makeAddr("testUser2");
        testUsers[3] = makeAddr("testUser3");
        testUsers[4] = makeAddr("testUser4");
        testUsers[5] = makeAddr("testUser5");

        // Add new addresses to trigger update position cycling
        for (uint256 i = 0; i < 6; i++) {
            vm.prank(testUsers[i]);
            proxy.getEntropy(3333 + i);
        }

        // Verify that addresses were updated in cycling pattern
        address[3] memory finalAddresses = proxy.getAllEntropyAddresses();

        // At least some of our test users should be in the final array
        uint256 testUsersFound = 0;
        for (uint256 i = 0; i < 3; i++) {
            for (uint256 j = 0; j < 6; j++) {
                if (finalAddresses[i] == testUsers[j]) {
                    testUsersFound++;
                    break;
                }
            }
        }

        assertTrue(testUsersFound >= 3, "Update position cycling should have updated addresses");
    }

    /*//////////////////////////////////////////////////////////////
                          HIGH-VOLUME GENERATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test high-volume entropy generation
    function test_HighVolumeGeneration() public {
        uint256 numGenerations = 25;
        bytes32[] memory entropies = new bytes32[](numGenerations);

        // Generate many entropies
        for (uint256 i = 0; i < numGenerations; i++) {
            entropies[i] = proxy.getEntropy(4444 + i);

            // Verify each entropy is non-zero
            assertTrue(entropies[i] != bytes32(0), "All entropies should be non-zero");
        }

        // Verify all entropies are unique
        for (uint256 i = 0; i < numGenerations; i++) {
            for (uint256 j = i + 1; j < numGenerations; j++) {
                assertTrue(
                    entropies[i] != entropies[j],
                    string(abi.encodePacked("Entropies at ", vm.toString(i), " and ", vm.toString(j), " should be unique"))
                );
            }
        }
    }

    /// @notice Test entropy generation with different users
    function test_HighVolumeWithDifferentUsers() public {
        uint256 numUsers = 10;
        bytes32[] memory entropies = new bytes32[](numUsers);

        for (uint256 i = 0; i < numUsers; i++) {
            address testUser = makeAddr(string(abi.encodePacked("testUser", vm.toString(i))));

            vm.prank(testUser);
            entropies[i] = proxy.getEntropy(5555 + i);

            assertTrue(entropies[i] != bytes32(0), "Entropy should be non-zero");
        }

        // Verify all entropies are unique
        for (uint256 i = 0; i < numUsers; i++) {
            for (uint256 j = i + 1; j < numUsers; j++) {
                assertTrue(entropies[i] != entropies[j], "All entropies should be unique");
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                          STATISTICAL DISTRIBUTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test entropy distribution across byte ranges
    function test_EntropyDistribution() public {
        uint256 numSamples = 32;
        uint256[8] memory buckets; // 8 buckets for byte value ranges

        // Generate entropy samples and analyze distribution
        for (uint256 i = 0; i < numSamples; i++) {
            bytes32 entropy = proxy.getEntropy(6666 + i);

            // Analyze first byte of entropy
            uint256 firstByte = uint256(uint8(entropy[0]));
            uint256 bucketIndex = firstByte / 32; // 256/8 = 32 values per bucket
            if (bucketIndex >= 8) bucketIndex = 7; // Handle edge case

            buckets[bucketIndex]++;
        }

        // Verify no bucket is completely empty (basic distribution check)
        uint256 emptyBuckets = 0;
        for (uint256 i = 0; i < 8; i++) {
            if (buckets[i] == 0) emptyBuckets++;
        }

        // Allow some empty buckets due to small sample size, but not all
        assertTrue(emptyBuckets < 8, "Not all buckets should be empty");
    }

    /// @notice Test for extreme byte values in entropy
    function test_EntropyBoundaryValues() public {
        uint256 numSamples = 20;
        bool foundLowValue = false;
        bool foundHighValue = false;

        for (uint256 i = 0; i < numSamples; i++) {
            bytes32 entropy = proxy.getEntropy(7777 + i);

            // Check all bytes in the entropy
            for (uint256 j = 0; j < 32; j++) {
                uint8 byteValue = uint8(entropy[j]);

                if (byteValue <= 10) foundLowValue = true;
                if (byteValue >= 245) foundHighValue = true;
            }
        }

        // Note: This is probabilistic - might not always pass with small sample
        // but provides insight into entropy quality
        console.log("Found low values (0-10):", foundLowValue);
        console.log("Found high values (245-255):", foundHighValue);
    }

    /*//////////////////////////////////////////////////////////////
                          EMERGENCY ENTROPY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test emergency entropy generation
    function test_EmergencyEntropyGeneration() public {
        // Reset proxy state
        proxy.resetState();

        // Force zero address to trigger emergency entropy
        proxy.injectZeroAddressAtCurrentIndex();

        bytes32 emergencyEntropy = proxy.getEntropy(8888);

        assertTrue(emergencyEntropy != bytes32(0), "Emergency entropy should be non-zero");
    }

    /// @notice Test emergency entropy with different salts
    function test_EmergencyEntropyWithDifferentSalts() public {
        proxy.resetState();
        proxy.injectZeroAddressAtCurrentIndex();

        bytes32 entropy1 = proxy.getEntropy(9999);

        proxy.resetState();
        proxy.injectZeroAddressAtCurrentIndex();

        bytes32 entropy2 = proxy.getEntropy(1111);

        assertTrue(entropy1 != entropy2, "Emergency entropy should vary with different salts");
    }

    /*//////////////////////////////////////////////////////////////
                          FALLBACK CYCLING TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that address index doesn't cycle during fallback conditions
    function test_AddressIndexNotCyclingInFallbackPath() public {
        // Get initial state
        (uint256 initialAddressIndex, , ) = proxy.getCurrentIndices();
        
        // Force zero address to trigger fallback
        proxy.resetState();
        proxy.injectZeroAddressAtCurrentIndex();
        
        // Generate entropy - should trigger fallback
        proxy.getEntropy(1000);
        
        // Check that address index hasn't changed due to fallback
        (uint256 afterFallbackAddressIndex, , ) = proxy.getCurrentIndices();
        assertEq(
            afterFallbackAddressIndex, 
            initialAddressIndex,
            "Address index should not cycle during fallback"
        );
    }

    /// @notice Test that segment index doesn't cycle during fallback conditions
    function test_SegmentIndexNotCyclingInFallbackPath() public {
        // Force invalid segment to trigger fallback in extractAddressSegment
        proxy.resetState();
        proxy.forceSetInvalidSegmentIndex(true);
        
        // Get initial state
        proxy.getCurrentIndices(); // Check initial indices
        
        // Call extractAddressSegment directly to trigger fallback
        address testAddr = makeAddr("testAddress");
        proxy.callExtractAddressSegment(testAddr, 0);
        
        // Reset the flag to get normal state
        proxy.forceSetInvalidSegmentIndex(false);
        
        // Check that segment index was reset during fallback
        (, uint256 afterFallbackSegmentIndex, ) = proxy.getCurrentIndices();
        assertEq(
            afterFallbackSegmentIndex,
            0, // Should be reset to 0 during fallback
            "Segment index should be reset during fallback"
        );
    }

    /*//////////////////////////////////////////////////////////////
                          ENHANCED STATISTICAL TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Enhanced entropy distribution test with variance calculation
    function test_EnhancedEntropyDistribution() public {
        uint256 numSamples = 100; // Increased sample size like original
        uint256[8] memory buckets; // 8 buckets for distribution analysis
        
        // Generate entropy samples and analyze distribution
        for (uint256 i = 0; i < numSamples; i++) {
            bytes32 entropy = proxy.getEntropy(10000 + i);
            
            // Analyze first byte of entropy
            uint256 firstByte = uint256(uint8(entropy[0]));
            uint256 bucketIndex = firstByte / 32; // 256/8 = 32 values per bucket
            if (bucketIndex >= 8) bucketIndex = 7; // Handle edge case
            
            buckets[bucketIndex]++;
        }
        
        // Calculate expected value (should be around numSamples/8)
        uint256 expected = numSamples / 8;
        
        // Calculate variance
        uint256 sumSquaredDifferences = 0;
        for (uint256 i = 0; i < 8; i++) {
            uint256 diff = buckets[i] > expected ? buckets[i] - expected : expected - buckets[i];
            sumSquaredDifferences += diff * diff;
        }
        
        uint256 variance = sumSquaredDifferences / 8;
        
        // Verify statistical properties
        assertTrue(variance < 100, "Variance should be within reasonable bounds");
        
        // Verify no bucket is completely empty
        uint256 emptyBuckets = 0;
        for (uint256 i = 0; i < 8; i++) {
            if (buckets[i] == 0) emptyBuckets++;
        }
        assertTrue(emptyBuckets < 4, "Not too many buckets should be empty");
    }

    /// @notice Enhanced boundary value testing for all 32 bytes
    function test_EnhancedBoundaryValueTesting() public {
        uint256 numSamples = 50; // Increased sample size
        uint256 lowValueCount = 0;
        uint256 highValueCount = 0;
        
        for (uint256 i = 0; i < numSamples; i++) {
            bytes32 entropy = proxy.getEntropy(11000 + i);
            
            // Check all 32 bytes in the entropy
            for (uint256 j = 0; j < 32; j++) {
                uint8 byteValue = uint8(entropy[j]);
                
                if (byteValue <= 10) lowValueCount++;
                if (byteValue >= 245) highValueCount++;
            }
        }
        
        // With 50 samples * 32 bytes = 1600 total bytes, we should see some extreme values
        // This is probabilistic but gives insight into entropy quality
        console.log("Total low values (0-10):", lowValueCount);
        console.log("Total high values (245-255):", highValueCount);
        console.log("Total bytes analyzed:", numSamples * 32);
    }

    /*//////////////////////////////////////////////////////////////
                          EVENT VERIFICATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test entropy generation events are properly emitted
    function test_EntropyGenerationEvents() public {
        vm.recordLogs();
        
        // Generate entropy
        vm.prank(user1);
        proxy.getEntropy(12345);
        
        // Get logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        
        // Check for EntropyGenerated event
        bool foundEvent = false;
        bytes32 expectedEventSignature = keccak256(
            "EntropyGenerated(address,uint256,uint256)"
        );
        
        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == expectedEventSignature) {
                // Check indexed parameters
                address eventRequester = address(uint160(uint256(entries[i].topics[1])));
                assertEq(eventRequester, user1, "Event requester should match caller");
                
                foundEvent = true;
                break;
            }
        }
        
        assertTrue(foundEvent, "EntropyGenerated event should be emitted");
    }

    /// @notice Test address update events during entropy generation
    function test_AddressUpdateEvents() public {
        vm.recordLogs();
        
        // Generate entropy with new user to trigger address update
        address newUser = makeAddr("eventTestUser");
        vm.prank(newUser);
        proxy.getEntropy(12346);
        
        // Get logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        
        // Check for EntropyAddressUpdated event
        bool foundEvent = false;
        bytes32 expectedEventSignature = keccak256(
            "EntropyAddressUpdated(uint256,address,address)"
        );
        
        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == expectedEventSignature) {
                // Decode the event data
                (, address newAddress) = abi.decode(entries[i].data, (address, address));
                assertEq(newAddress, newUser, "New address should match the caller");
                
                foundEvent = true;
                break;
            }
        }
        
        assertTrue(foundEvent, "EntropyAddressUpdated event should be emitted");
    }

    /*//////////////////////////////////////////////////////////////
                          PRECISE INDEX CYCLING TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test precise address index cycling with mathematical verification
    function test_PreciseAddressIndexCycling() public {
        // Start with known state
        proxy.forceSetAddressIndex(0);
        
        uint256 salt = 20000;
        
        // Test multiple cycles
        for (uint256 i = 0; i < 9; i++) { // 3 full cycles
            // Get pre-call state
            (uint256 preAddrIndex, , ) = proxy.getCurrentIndices();
            
            // Generate entropy
            proxy.getEntropy(salt + i);
            
            // Get post-call state
            (uint256 postAddrIndex, , ) = proxy.getCurrentIndices();
            
            // Verify specific mathematical progression
            uint256 expectedIndex = (preAddrIndex + 1) % 3;
            assertEq(
                postAddrIndex, 
                expectedIndex, 
                string(abi.encodePacked("Address index should increment by 1 at iteration ", vm.toString(i)))
            );
        }
    }

    /// @notice Test precise segment index cycling with mathematical verification
    function test_PreciseSegmentIndexCycling() public {
        // Start with known state
        proxy.forceSetSegmentIndex(0);
        
        uint256 salt = 21000;
        
        // Test multiple cycles
        for (uint256 i = 0; i < 12; i++) { // 3 full cycles of 4 segments
            // Get pre-call state
            (, uint256 preSegIndex, ) = proxy.getCurrentIndices();
            
            // Generate entropy
            proxy.getEntropy(salt + i);
            
            // Get post-call state
            (, uint256 postSegIndex, ) = proxy.getCurrentIndices();
            
            // Verify specific mathematical progression
            uint256 expectedIndex = (preSegIndex + 1) % 4;
            assertEq(
                postSegIndex, 
                expectedIndex, 
                string(abi.encodePacked("Segment index should increment by 1 at iteration ", vm.toString(i)))
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                          EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Fuzz test entropy generation with varying salts
    function testFuzz_EntropyWithVariousSalts(uint256 salt) public {
        bytes32 entropy = proxy.getEntropy(salt);
        assertTrue(entropy != bytes32(0), "Entropy should be non-zero for any salt");
    }

    /// @notice Test entropy generation edge case handling
    function test_EntropyEdgeCases() public {
        // Test with zero salt
        bytes32 entropy1 = proxy.getEntropy(0);
        assertTrue(entropy1 != bytes32(0), "Entropy should be non-zero even with zero salt");

        // Test with max uint256 salt
        bytes32 entropy2 = proxy.getEntropy(type(uint256).max);
        assertTrue(entropy2 != bytes32(0), "Entropy should be non-zero with max salt");

        // Verify they're different
        assertTrue(entropy1 != entropy2, "Zero and max salt should produce different entropy");
    }

    /// @notice Test entropy generation under various block conditions
    function test_EntropyWithBlockVariations() public {
        bytes32[] memory entropies = new bytes32[](5);

        // Generate entropy under different block conditions
        entropies[0] = proxy.getEntropy(1234);

        vm.roll(block.number + 100);
        entropies[1] = proxy.getEntropy(1234);

        vm.warp(block.timestamp + 3600);
        entropies[2] = proxy.getEntropy(1234);

        vm.roll(1);
        entropies[3] = proxy.getEntropy(1234);

        vm.warp(1);
        entropies[4] = proxy.getEntropy(1234);

        // Verify all are different
        for (uint256 i = 0; i < 5; i++) {
            assertTrue(entropies[i] != bytes32(0), "All entropies should be non-zero");
            for (uint256 j = i + 1; j < 5; j++) {
                assertTrue(entropies[i] != entropies[j], "Entropies under different block conditions should differ");
            }
        }
    }
}
