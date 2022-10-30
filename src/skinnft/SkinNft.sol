// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./ERC721A.sol";
import "./ISkinNft.sol";

contract SkinNFT is ISkinNft, ERC721A {
    constructor() ERC721A("ChainInsightSkin", "CHAIN_INSIGHT_SKIN") {}

    address public sbtInterfaceAddress;
    mapping(address => uint) freemintQuantity;

    function init(address sbtAddress) external {
        require(
            sbtInterfaceAddress == address(0),
            "The contract is already initialized"
        );
        sbtInterfaceAddress = sbtAddress;
    }

    function mint(uint256 quantity) external payable {
        // `_mint`'s second argument now takes in a `quantity`, not a `tokenId`.
        _mint(msg.sender, quantity);
    }

    function setFreemintQuantity(address _address, uint256 quantity) external {
        require(
            msg.sender == sbtInterfaceAddress,
            "SET FREEMINT IS ONLY ALLOWED TO SBT CONTRACT"
        );
        freemintQuantity[_address] += quantity;
    }

    function check_free_mintable(address _address)
        external
        view
        returns (uint256)
    {
        return freemintQuantity[_address];
    }

    function free_mint() external returns (uint256) {
        uint256 quantity = freemintQuantity[msg.sender];
        require(quantity != 0, "NOT FREEMINTABLE");
        freemintQuantity[msg.sender] = 0;
        uint256 nextTokenId = _nextTokenId();
        _mint(msg.sender, quantity);
        return nextTokenId;
    }
}
