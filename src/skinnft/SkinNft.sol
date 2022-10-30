// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "erc721a/contracts/ERC721A.sol";
import "./../sbt/ISbt.sol";

contract Azuki is ERC721A {
    constructor() ERC721A("ChainInsightSkin", "CHAIN_INSIGHT_SKIN") {}
    uint256 freemintNftPoints = 6;

    address public sbtInterfaceAddress;
    ISbt sbtContract;

    function mint(uint256 quantity) external payable {
        // `_mint`'s second argument now takes in a `quantity`, not a `tokenId`.
        _mint(msg.sender, quantity);
    }

    function setSbtInterfaceAddress(address _address) external {
        sbtInterfaceAddress = _address;
        sbtContract = ISbt(sbtInterfaceAddress);
    }

    function check_free_mintable(address _address) external view returns (uint256){
        return sbtContract.getNftPoints(_address);
    }
    
    function free_mint(address _address, uint256 quantity) external returns (uint256){
        uint256 nftPoints = sbtContract.getNftPoints(_address);
        require(nftPoints >= freemintNftPoints * quantity , "NOT FREEMINTABLE");
        uint256 nextTokenId = _nextTokenId();
        _mint(msg.sender, quantity);
        nftPoints -= freemintNftPoints * quantity;
        sbtContract.setNftPoints(_address, nftPoints);
        return nextTokenId;
    }
}