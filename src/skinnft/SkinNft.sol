// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./ERC721AQueryable.sol";
import "./ERC721A.sol";
import "./ISkinNft.sol";

contract SkinNft is ISkinNft, ERC721AQueryable {
    string baseURI;

    constructor(string memory _baseURI)
        ERC721AQueryable("ChainInsightSkin", "CHAIN_INSIGHT_SKIN")
    {
        baseURI = _baseURI;
    }

    address sbtAddress;
    mapping(address => uint256) public freemintQuantity;
    mapping(address => uint256) public _icon;

    function init(address _sbtAddress) external {
        require(
            sbtAddress == address(0),
            "The contract is already initialized"
        );
        sbtAddress = _sbtAddress;
    }

    function mint(uint256 quantity) external payable {
        // `_mint`'s second argument now takes in a `quantity`, not a `tokenId`.
        _mint(msg.sender, quantity);
    }

    function getIcon(address _address) external view returns (uint256) {
        return _icon[_address];
    }

    function setIcon(uint256 tokenId) external {
        require(
            ownerOf(tokenId) == msg.sender,
            "THE TOKEN IS OWNED BY OTHER PERSON"
        );
        _icon[msg.sender] = tokenId;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable override(ERC721AQueryable) {
        require(_icon[from] != tokenId, "THE TOKEN IS SET TO YOUR ICON");
        super.transferFrom(from, to, tokenId);
    }

    function getFreemintQuantity(address _address)
        external
        view
        returns (uint256)
    {
        return freemintQuantity[_address];
    }

    function setFreemintQuantity(address _address, uint256 quantity) external {
        require(
            msg.sender == sbtAddress,
            "SET FREEMINT IS ONLY ALLOWED TO SBT CONTRACT"
        );
        freemintQuantity[_address] += quantity;
    }

    function freeMint() external returns (uint256) {
        uint256 quantity = freemintQuantity[msg.sender];
        require(quantity != 0, "NOT FREEMINTABLE");
        uint256 nextTokenId = _nextTokenId();
        _mint(msg.sender, freemintQuantity[msg.sender]);
        freemintQuantity[msg.sender] = 0;
        return nextTokenId;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newBaseURI) external {
        require(
            msg.sender == sbtAddress,
            "setBaseURI is only allowed to SBT CONTRACT"
        );
        baseURI = _newBaseURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721A)
        returns (string memory)
    {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();
        return
            bytes(baseURI).length != 0
                ? string(abi.encodePacked(baseURI, _toString(tokenId), ".json"))
                : "";
    }

    function withdraw() external {
        require(
            msg.sender == sbtAddress,
            "WITHDRAW IS ONLY ALLOWED TO SBT CONTRACT"
        );
        payable(msg.sender).transfer(address(this).balance);
    }
}
