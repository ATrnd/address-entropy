// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AddressEntropyConstants} from "../constants/AddressEntropyConstants.sol";

/**
 * @title AddressValidationLibrary
 * @notice Pure utility functions for address and value validation
 * @dev Contains validation logic extracted from AddressDataEntropy
 * @author ATrnd
 */
library AddressValidationLibrary {

    /*//////////////////////////////////////////////////////////////
                         ADDRESS VALIDATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks if an address is the zero address
    /// @param addr The address to check
    /// @return True if the address is zero
    function isZeroAddress(address addr) internal pure returns (bool) {
        return addr == AddressEntropyConstants.ZERO_ADDRESS;
    }

    /*//////////////////////////////////////////////////////////////
                         VALUE VALIDATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks if a value is zero
    /// @param value The value to check
    /// @return True if the value is zero
    function isZeroValue(uint256 value) internal pure returns (bool) {
        return value == AddressEntropyConstants.ZERO_UINT;
    }

    /*//////////////////////////////////////////////////////////////
                         MSG.SENDER VALIDATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks if the message sender is zero address
    /// @return True if msg.sender is zero address
    function isMsgSenderZero() internal view returns (bool) {
        return msg.sender == AddressEntropyConstants.ZERO_ADDRESS;
    }

}
