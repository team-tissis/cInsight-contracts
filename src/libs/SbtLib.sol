// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

library SbtLib {
    bytes32 constant SBT_STRUCT_POSITION = keccak256("chaininsight");

    struct SbtStruct {
        address contractOwner;
        string name;
        string symbol;
        string baseURI;
        bytes32 validator;
        mapping(bytes4 => bool) interfaces;
        mapping(address => uint256) balances;
    }

    // get struct stored at posititon
    function sbtStorage() internal pure returns (SbtStruct storage sbtstruct) {
        bytes32 position = SBT_STRUCT_POSITION;
        assembly {
            sbtstruct.slot := position
        }
    }
}