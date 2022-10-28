// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "erc721a/contracts/ERC721A.sol";
import "./../sbt/ISbt.sol"

contract Azuki is ERC721A {
    constructor() ERC721A("ChainInsightSkin", "CHAIN_INSIGHT_SKIN") {
    }

    address public sbtInterfaceAddress;
    SbtInterface sbtContract;

    function mint(uint256 quantity) external payable {
        // `_mint`'s second argument now takes in a `quantity`, not a `tokenId`.
        _mint(msg.sender, quantity);
    }

    function setSbtInterfaceAddress(address _address) external {
        sbtInterfaceAddress = _address;
        SbtInterface sbtContract = SbtInterface(BloodInterfaceAddress);
    }

    function check_free_mintable(address) external view {
        sbtContract.get;
        
    }
    
    function free_mint() external{
        require()
    }
}