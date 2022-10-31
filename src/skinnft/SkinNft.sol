// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./ERC721A.sol";
import "./ISkinNft.sol";

contract SkinNft is ISkinNft, ERC721A {
    string baseURI;

    constructor(string memory _baseURI)
        ERC721A("ChainInsightSkin", "CHAIN_INSIGHT_SKIN")
    {
        baseURI = _baseURI;
    }

    address sbtInterfaceAddress;
    mapping(address => uint256) public freemintQuantity;
    mapping(address => uint256) public _icon;

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
    ) public payable override(ERC721A) {
        require(_icon[from] != tokneId, "THE TOKEN IS SET TO YOUR ICON");
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
            msg.sender == sbtInterfaceAddress,
            "SET FREEMINT IS ONLY ALLOWED TO SBT CONTRACT"
        );
        freemintQuantity[_address] += quantity;
    }

    function checkFreeMintable(address _address)
        external
        view
        returns (uint256)
    {
        return freemintQuantity[_address];
    }

    function freeMint() external returns (uint256) {
        uint256 quantity = freemintQuantity[msg.sender];
        require(quantity != 0, "NOT FREEMINTABLE");
        freemintQuantity[msg.sender] = 0;
        uint256 nextTokenId = _nextTokenId();
        _mint(msg.sender, quantity);
        return nextTokenId;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        return string(abi.encodePacked(baseURI, toString(_tokenId), ".json"));
    }

    function withdraw() external {
        require(
            msg.sender == sbtInterfaceAddress,
            "WITHDRAW IS ONLY ALLOWED TO SBT CONTRACT"
        );
        payable(owner()).transfer(address(this).balance);
    }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            unchecked {
                digits++;
                temp /= 10;
            }
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            unchecked {
                digits -= 1;
                buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
                value /= 10;
            }
        }
        return string(buffer);
    }
}
