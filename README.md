# AddressDataEntropy

![Solidity](https://img.shields.io/badge/Solidity-0.8.28-363636?style=flat&logo=solidity)
![Foundry](https://img.shields.io/badge/Foundry-Latest-000000?style=flat)
![License](https://img.shields.io/badge/License-MIT-green?style=flat)
![Build](https://img.shields.io/badge/Build-Passing-success?style=flat)

**[⚡] Address-based entropy engine // 160→40bit segmentation // Crash-immune design**

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

### Never-Fail Guarantee
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

### Error Monitoring
- **Component tracking**: 5 components × 6 error types = 30 counters
- **Event emission**: `SafetyFallbackTriggered` with component/function/error
- **State persistence**: Error counts stored in `mapping(uint8 => mapping(uint8 => uint256))`
- **Health queries**: View functions expose all error statistics

## Architecture

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

## Core Functions

### Entropy Generation
- `getEntropy(uint256 salt)` - Generate entropy with salt

### State Monitoring
- `getComponentErrorCount(uint8 componentId, uint8 errorCode)` - Error count by component/type
- `getComponentTotalErrorCount(uint8 componentId)` - Total errors for component
- `hasComponentErrors(uint8 componentId)` - Check if component has errors

### Component-Specific Error Queries
- `getAddressExtractionZeroAddressCount()` - Zero address errors
- `getSegmentExtractionZeroSegmentCount()` - Zero segment errors
- `getSegmentExtractionOutOfBoundsCount()` - Index out of bounds errors
- `getEntropyGenerationZeroAddressCount()` - Zero address in generation
- `getEntropyGenerationZeroSegmentCount()` - Zero segment in generation
- `getEntropyGenerationCycleDisruptionCount()` - Cycle disruption errors

### Ownership
- `owner()` - Get contract owner
- `transferOwnership(address newOwner)` - Transfer ownership
- `renounceOwnership()` - Renounce ownership

## Deployments

| Network | Address | Explorer |
|---------|---------|----------|
| Sepolia | `0x0a6a8bd517423412b2c5ce059308bdb47c19b138` | [View](https://sepolia.etherscan.io/address/0x0a6a8bd517423412b2c5ce059308bdb47c19b138) |
| Shape Mainnet | `0x7E219429Af91E3a455Ed70A24C09FCbCa8C65F86` | [View](https://shapescan.xyz/address/0x7E219429Af91E3a455Ed70A24C09FCbCa8C65F86) |

## Usage

```solidity
// Generate entropy
bytes32 entropy = contract.getEntropy(12345);

// Check system health
bool hasErrors = contract.hasComponentErrors(1);
uint256 errorCount = contract.getComponentTotalErrorCount(1);
```
