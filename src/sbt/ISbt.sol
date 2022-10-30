// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;
interface ISbt {
    function getNftPoints(address user_address) external view returns (uint16);

}
