// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;
import "./../skinnft/ISkinNft.sol";

library SbtLib {
    bytes32 constant SBT_STRUCT_POSITION = keccak256("chaininsight");

    struct SbtStruct {
        address admin;
        string name;
        string symbol;
        string baseURI;
        mapping(bytes4 => bool) interfaces;
        mapping(uint256 => address) owners; // token_id -> address
        mapping(address => uint) favos; // favoした回数
        mapping(address => uint) makis;
        mapping(address => uint) grades;
        mapping(address => uint) makiMemorys;
        mapping(address => uint) referrals; // リファラルした回数
        mapping(address => address) referralMap; // mapping(to => from)
        uint8[] referralRate; // referal rate. grade 1, 2, 3, 4, 5
        uint8[] skinnftNumRate; // allocated skinnft for each grade. grade 1, 2, 3, 4, 5
        uint8[] gradeRate; // percentage of each grade. grade 1, 2, 3, 4, 5
        uint256 sbtPrice;
        uint256 sbtReferralPrice;
        uint256 sbtReferralIncentive;
        address nftAddress;
        uint16 mintIndex;
        uint16 burnNum;
        uint16 monthlyDistributedFavoNum;
        uint8 gradeNum;
        uint8 lastUpdatedMonth;
        uint8 favoUseUpIncentive;
        uint8 makiDecayRate;
    }

    // get struct stored at posititon
    //https://solidity-by-example.org/app/write-to-any-slot/
    function sbtStorage() internal pure returns (SbtStruct storage sbtstruct) {
        /** メモ: @shion
         * slot: storageは32バイトの領域を確保するが，その領域をslotと呼ぶ
         * positionのstrunctを参照する
         */
        bytes32 position = SBT_STRUCT_POSITION;
        assembly {
            sbtstruct.slot := position
        }
    }
}
