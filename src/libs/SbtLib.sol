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
        mapping(address => uint16) address2index;
        uint8[] favoList; // favoした回数
        uint16[] makiList;
        uint8[] gradeList;
        uint32[] rateList;
        uint8[] referralList; // リファラルした回数
        uint8[] nftPointsList; // nft付与権限

        mapping(address => mapping (string => uint8)) maxstarMap; // 各ユーザーの各ジャンルタグの最大のスター数
        mapping(bytes4 => bool) interfaces;
    }

    // get struct stored at posititon
    //https://solidity-by-example.org/app/write-to-any-slot/
    function sbtStorage() internal pure returns (SbtStruct storage sbtstruct) {
        /** メモ: @shion
         * slot: storageは32バイトの領域を確保するが，その領域をslotと呼ぶ
         * positionのstrunctを取得する
         */
        bytes32 position = SBT_STRUCT_POSITION;
        assembly {
            sbtstruct.slot := position
        }
    }
}