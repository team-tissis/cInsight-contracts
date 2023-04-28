// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./ERC721AQueryable.sol";
import "./ISkinNft.sol";
import "./../bonfire/IBonfireProxy.sol";

contract SkinNft is ERC721AQueryable, ISkinNft {
    string public baseURI;
    uint256 colorNum;

    constructor(string memory _baseURI, uint256 _colorNum)
        ERC721A("ChainInsightSkin", "CHAIN_INSIGHT_SKIN")
    {
        baseURI = _baseURI;
        colorNum = _colorNum;
    }

    address bonfireAddress;
    IBonfire internal bonfire;
    mapping(address => uint256) public freemintQuantity;
    mapping(address => uint256) public _icon; // NFT ホルダーのアドレス <-> NFT の token id

    function init(address _bonfireAddress) external {
        require(
            bonfireAddress == address(0),
            "The contract is already initialized"
        );
        bonfireAddress = _bonfireAddress;
        bonfire = IBonfire(_bonfireAddress);
    }

    // TODO: implemente mint function and auction.
    // function mint(uint256 quantity) external payable {
    //     // `_mint`'s second argument now takes in a `quantity`, not a `tokenId`.
    //     _mint(msg.sender, quantity);
    // }
    // NFT が発行されていないアドレスに対しては、0 が返される。
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

    function IconURI(address _address) external view returns (string memory) {
        require(bonfire.gradeOf(_address) != 0, "address dosn't hold SBT");
        uint256 iconId = _icon[_address];
        if (iconId == 0) {
            uint256 bonfireTokenId = bonfire.tokenIdOf(_address);
            return bonfire.tokenURI(bonfireTokenId);
        } else {
            return tokenURI(iconId);
        }
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable override(IERC721A, ERC721A) {
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
            msg.sender == bonfireAddress,
            "SET FREEMINT IS ONLY ALLOWED TO SBT CONTRACT"
        );
        freemintQuantity[_address] += quantity;

        // TODO: This airdrop code is for Hackathon. stop airdrop.
        require(quantity != 0, "NOT FREEMINTABLE");
        uint256 nextTokenId = _nextTokenId();
        _mint(_address, freemintQuantity[_address]);
        freemintQuantity[_address] = 0;
        // 自動でiconに設定
        _icon[_address] = nextTokenId;
        return;
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
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
            msg.sender == bonfireAddress,
            "setBaseURI is only allowed to SBT CONTRACT"
        );
        baseURI = _newBaseURI;
    }

    function withdraw() external {
        require(
            msg.sender == bonfireAddress,
            "WITHDRAW IS ONLY ALLOWED TO SBT CONTRACT"
        );
        payable(msg.sender).transfer(address(this).balance);
    }

    function _colorNum() external view returns (uint256) {
        return colorNum;
    }


    /**
     * @notice Gets the token ids owned by address
     * @param _address Target address
     * @return uint256[] memory
     */
    function tokenIdsOf(address _address) public view returns (uint256[] memory) {
        uint256 totalTokenNum = _nextTokenId() - 1;
        uint256[] memory tokenIds = new uint256[](totalTokenNum);
        uint256 counter = 0;
        for (uint256 tokenId = 1; tokenId < totalTokenNum + 1; tokenId++) {
            if (_address == ownerOf(tokenId)) {
                tokenIds[counter] = tokenId;
                counter++;
            }
        }

        // resize array
        uint256[] memory resultTokenIds = new uint256[](counter);
        for (uint256 i = 0; i < counter; i++) {
            resultTokenIds[i] = tokenIds[i];
        }
        return resultTokenIds;
    }
}
