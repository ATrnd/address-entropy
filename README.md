# AddressEntropy

![Banner](https://github.com/ATrnd/address-entropy/blob/main/img/address-entropy-banner.jpg?raw=true)

![Solidity](https://img.shields.io/badge/Solidity-0.8.28-363636?style=flat&logo=solidity)
![Foundry](https://img.shields.io/badge/Foundry-Latest-000000?style=flat)
![License](https://img.shields.io/badge/License-MIT-green?style=flat)
![Build](https://img.shields.io/badge/Build-Passing-success?style=flat)

**[⚡] Address-based entropy engine // 160→40bit segmentation // Crash-immune design**

## Table of Contents

- [Overview](#overview)
- [Engine Mechanics](#engine-mechanics)
  - [Address Segmentation](#address-segmentation)
  - [Cycling System](#cycling-system)
  - [Entropy Combination](#entropy-combination)
  - [Fallback Chain](#fallback-chain)
- [Protection Mechanics](#protection-mechanics)
  - [Invalid Data Handling](#invalid-data-handling)
  - [Fallback Architecture](#fallback-architecture)
- [Core Architecture](#core-architecture)
- [Function Reference](#function-reference)
  - [Public Functions](#public-functions)
  - [Internal Functions](#internal-functions)
  - [Library Functions](#library-functions)
- [Deployments](#deployments)
- [Quick Start](#quick-start)

## Overview

Generates entropy by extracting 40-bit segments from addresses and combining with block data, transaction context, and cycling state.

## Engine Mechanics

### Address Segmentation
- **160-bit addresses** split into **4x40-bit segments**
- **Bit shifting**: `(addr >> shift) & 0xFFFFFFFFFF`
- **Shifts**: 0, 40, 80, 120 bits for segments 0-3

### Cycling System
- **Address cycling**: 3 addresses → index % 3
- **Segment cycling**: 4 segments → index % 4
- **Update cycling**: Overwrites oldest address with msg.sender
- **Transaction counter**: Increments per entropy request

### Entropy Combination
```
keccak256(
  currentSegment,     // 40-bit from current address[i] segment[j]
  segmentIndex,       // Which segment (0-3)
  block.timestamp,    // Block context
  block.number,
  block.prevrandao,
  msg.sender,         // Caller context
  salt,               // User input
  txCounter,          // Request number
  stateHash           // Address array hash
)
```

### Fallback Chain
1. **Zero address** → Generate fallback segment from block data
2. **Zero segment** → Use `keccak256(timestamp, number, index)`
3. **Index overflow** → Reset to 0, continue with fallback
4. **Emergency entropy** → Pure block/transaction data combination

## Protection Mechanics

### Invalid Data Handling
| Scenario | Detection | Response | Error Tracking |
|----------|-----------|----------|----------------|
| **Zero Address Input** | `addr == address(0)` | Generate fallback segment | Component ID 1, Error 1 |
| **Segment Index OOB** | `index >= 4` | Reset to 0, use fallback | Component ID 2, Error 4 |
| **Zero Segment Extract** | `segment == 0` | Generate deterministic fallback | Component ID 2, Error 3 |
| **msg.sender == 0** | Edge case check | Skip state update, log error | Component ID 3, Error 1 |
| **Extraction Failure** | Try-catch on segment ops | Emergency entropy path | Component ID varies |

### Fallback Architecture
```
getEntropy() → ALWAYS returns bytes32
    │
    ├── Normal Path: Extract → Combine → Return
    │
    └── Failure Path: Emergency → Combine → Return
        │
        └── Uses: block.timestamp + block.number +
                  msg.sender + salt + error_counts
```

## Core Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Address[3]    │    │  Segment Extract │    │    Entropy      │
│   Cycling Pool  │───▶│  (4x40-bit segs) │───▶│   Generation    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                       │
         ▼                        ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Update Position │    │  Fallback Safety │    │   bytes32       │
│ Auto-cycling    │    │  Zero Protection │    │   Output        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Function Reference

### Public Functions

#### Core Entropy Generation
- `getEntropy(uint256 salt) external returns (bytes32)` - Primary entropy generation function with user-provided salt

#### Error Monitoring & Health Checks
- `getComponentErrorCount(uint8 componentId, uint8 errorCode) external view returns (uint256)` - Get specific error count for component/error pair
- `getComponentTotalErrorCount(uint8 componentId) external view returns (uint256)` - Get total error count for a component
- `hasComponentErrors(uint8 componentId) external view returns (bool)` - Check if component has any errors

#### Component-Specific Error Queries
- `getAddressExtractionZeroAddressCount() external view returns (uint256)` - Zero address errors in address extraction
- `getSegmentExtractionZeroSegmentCount() external view returns (uint256)` - Zero segment errors in segment extraction
- `getSegmentExtractionOutOfBoundsCount() external view returns (uint256)` - Out of bounds errors in segment extraction
- `getEntropyGenerationZeroAddressCount() external view returns (uint256)` - Zero address errors in entropy generation
- `getEntropyGenerationZeroSegmentCount() external view returns (uint256)` - Zero segment errors in entropy generation
- `getEntropyGenerationCycleDisruptionCount() external view returns (uint256)` - Cycle disruption errors in entropy generation

#### Ownership (Inherited from OpenZeppelin)
- `owner() external view returns (address)` - Get current contract owner
- `transferOwnership(address newOwner) external` - Transfer ownership to new address
- `renounceOwnership() external` - Renounce ownership (sets owner to zero address)

### Internal Functions

#### Core Processing
- `_extractAddressSegment(address addr, uint256 segmentIndex) internal returns (bytes5)` - Extract specific 40-bit segment from address
- `_updateEntropyState() internal` - Update cycling indices and address array after entropy generation
- `_tryUpdateAddress(address newAddress) internal returns (bool)` - Attempt to add new address to entropy pool
- `_incrementTransactionCounter() internal returns (uint256)` - Increment and return transaction counter

#### Fallback & Error Handling
- `_handleFallback(uint8 componentId, string memory functionName, uint8 errorCode) internal` - Handle fallback events with tracking
- `_incrementComponentErrorCount(uint8 componentId, uint8 errorCode) internal returns (uint256)` - Increment error counters
- `_generateEmergencyEntropy(uint256 salt, uint256 txCounter) internal view returns (bytes32)` - Generate emergency entropy when normal flow fails
- `_getComponentName(uint8 componentId) internal pure returns (string memory)` - Convert component ID to name string

### Library Functions

#### AddressSegmentLibrary
- `extractSegmentWithShift(address addr, uint256 segmentIndex) internal pure returns (uint40)` - Core bit-shifting segment extraction
- `generateFallbackSegment(uint256 segmentIndex) internal view returns (bytes5)` - Generate deterministic fallback segment
- `generateFallbackSegments() internal view returns (bytes5[4] memory)` - Generate all fallback segments for zero address
- `isSegmentIndexValid(uint256 segmentIndex) internal pure returns (bool)` - Validate segment index (0-3)
- `isZeroSegment(uint40 segment) internal pure returns (bool)` - Check if extracted segment is zero
- `isZeroByteArray(bytes5 value) internal pure returns (bool)` - Check if bytes5 value is zero

#### AddressCyclingLibrary
- `cycleAddressIndex(uint256 currentIndex) internal pure returns (uint256)` - Cycle through address array indices
- `cycleSegmentIndex(uint256 currentIndex) internal pure returns (uint256)` - Cycle through segment indices
- `cycleUpdatePosition(uint256 currentPosition) internal pure returns (uint256)` - Cycle through update positions
- `incrementTransactionCounter(uint256 currentCounter) internal pure returns (uint256)` - Increment transaction counter

#### AddressValidationLibrary
- `isZeroAddress(address addr) internal pure returns (bool)` - Check if address is zero
- `isZeroValue(uint256 value) internal pure returns (bool)` - Check if uint256 value is zero
- `isMsgSenderZero() internal view returns (bool)` - Check if msg.sender is zero address
- `shouldHandleExtractionError(bool success) internal pure returns (bool)` - Determine if extraction error needs handling

#### AddressFallbackLibrary
- `getComponentName(uint8 componentId) internal pure returns (string memory)` - Get component name from ID
- `incrementComponentErrorCount(uint256 currentCount) internal pure returns (uint256)` - Safely increment error count
- `generateEmergencyEntropy(uint256 salt, uint256 txCounter, uint256 zeroAddressCount, uint256 zeroSegmentCount) internal view returns (bytes32)` - Generate emergency entropy with error counts

## Deployments

| Network | Address | Explorer |
|---------|---------|----------|
| Sepolia | `0x0a6a8bd517423412b2c5ce059308bdb47c19b138` | [View](https://sepolia.etherscan.io/address/0x0a6a8bd517423412b2c5ce059308bdb47c19b138) |
| Shape Mainnet | `0x7E219429Af91E3a455Ed70A24C09FCbCa8C65F86` | [View](https://shapescan.xyz/address/0x7E219429Af91E3a455Ed70A24C09FCbCa8C65F86) |

## Quick Start

### Prerequisites

- [Foundry](https://getfoundry.sh/) installed
- [Git](https://git-scm.com/) installed
- Solidity 0.8.28+

### Installation

#### Clone the Repository
```bash
git clone git@github.com:ATrnd/address-entropy.git
cd address-entropy
```

#### Install Dependencies
```bash
forge install
```

#### Build the Project
```bash
forge build
```

#### Run Tests
```bash
forge test
```
