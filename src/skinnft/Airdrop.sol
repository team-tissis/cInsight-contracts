// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

contract Airdrop {

    modifier onlyOwner() {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(msg.sender == sbtstruct.contractOwner,"OWNER ONLY");
        _;
    }

    event Transfer(
        address 
    )