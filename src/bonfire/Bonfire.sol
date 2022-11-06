// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./../libs/BonfireLib.sol";
import "./IBonfire.sol";
import "./../skinnft/ISkinNft.sol";

contract Bonfire is IBonfire {
    modifier onlyExecutor() {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        require(msg.sender == BonfireStruct.executor, "EXECUTOR ONLY");
        _;
    }

    function init(
        address _executor,
        string calldata _name,
        string calldata _symbol,
        string calldata _baseURI,
        uint256 _sbtPrice,
        address _nftAddress,
        address _impAddress
    ) external {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        require(_executor != address(0), "_executor must not be address 0");
        require(BonfireStruct.executor == address(0), "INITIATED ALREADY");
        BonfireStruct.executor = _executor;
        BonfireStruct.admin = msg.sender;
        BonfireStruct.name = _name;
        BonfireStruct.symbol = _symbol;
        BonfireStruct.baseURI = _baseURI;
        BonfireStruct.nftAddress = _nftAddress;
        BonfireStruct.interfaces[(bytes4)(0x01ffc9a7)] = true; //ERC165
        BonfireStruct.interfaces[(bytes4)(0x5b5e139f)] = true; //ERC721metadata
        BonfireStruct.sbtPrice = _sbtPrice;
        BonfireStruct.sbtReferralPrice = _sbtPrice / 2;
        BonfireStruct.sbtReferralIncentive = _sbtPrice / 4;
        BonfireStruct.monthlyDistributedFavoNum = 10;
        BonfireStruct.lastUpdatedMonth = 0; //initial value for last updated month
        BonfireStruct.favoUseUpIncentive = 1;
        BonfireStruct.makiDecayRate = 90;
        BonfireStruct.gradeNum = 5; // currently grade num is immutable and is set 5. TODO: change to mutable
        uint8[5] memory _referralRate = [1, 1, 1, 3, 5]; // grade 1,2,3,4,5
        uint8[5] memory _skinnftNumRate = [0, 0, 0, 1, 2]; // grade 1,2,3,4,5
        uint8[5] memory _gradeRate = [80, 60, 40, 20, 0]; // the percentage of grade 1,2,3,4,5

        for (uint256 i = 0; i < 5; i++) {
            BonfireStruct.referralRate.push(_referralRate[i]);
            BonfireStruct.skinnftNumRate.push(_skinnftNumRate[i]);
            BonfireStruct.gradeRate.push(_gradeRate[i]);
        }

        bytes4[] memory sigs = new bytes4[](7);
        sigs[0] = bytes4(keccak256("mint()"));
        sigs[1] = bytes4(keccak256("mintWithReferral(address)"));
        sigs[2] = bytes4(keccak256("burn(uint)"));
        sigs[3] = bytes4(keccak256("setFreemintQuantity(address,uint256)"));
        sigs[4] = bytes4(keccak256("monthInit()"));
        sigs[5] = bytes4(keccak256("addFavos(address,uint8)"));
        sigs[6] = bytes4(keccak256("refer(address)"));

        for (uint256 i = 0; i < sigs.length; i++) {
            unchecked {
                implementations[sigs[i]] = _impAddress;
            }
        }
    }

    mapping(bytes4 => address) public implementations;

    // storage type に calldataを用いると変数はimmutableになりガス代節約できる。
    function setImplementation(
        bytes4[] calldata _sigs,
        address[] calldata _impAddress
    ) external {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        require(msg.sender == BonfireStruct.executor, "EXECUTOR ONLY");
        require(_sigs.length == _impAddress.length, "INVALID LENGTH");
        for (uint256 i = 0; i < _sigs.length; i++) {
            unchecked {
                implementations[_sigs[i]] = _impAddress[i];
            }
        }
    }

    // get functions
    function executor() external view returns (address) {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        return BonfireStruct.executor;
    }

    function admin() external view returns (address) {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        return BonfireStruct.admin;
    }

    // supportしているERCversionなど
    function supportsInterface(bytes4 _interfaceID)
        external
        view
        returns (bool)
    {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        return BonfireStruct.interfaces[_interfaceID];
    }

    function name() external view returns (string memory) {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        return BonfireStruct.name;
    }

    //0x95d89b41
    function symbol() external view returns (string memory) {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        return BonfireStruct.symbol;
    }

    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        address _owner = BonfireStruct.owners[_tokenId];
        require(
            _owner != address(0),
            "ERC721URIStorage: URI query for nonexistent token"
        );
        uint256 skinNftTokenId = ISkinNft(BonfireStruct.nftAddress).getIcon(
            _owner
        );
        return
            string(
                abi.encodePacked(
                    BonfireStruct.baseURI,
                    _toString(skinNftTokenId),
                    "/",
                    _toString(BonfireStruct.grades[_owner]),
                    "/",
                    _toString(_tokenId)
                )
            );
    }

    function ownerOf(uint256 _tokenId) external view returns (address) {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        return BonfireStruct.owners[_tokenId];
    }

    function tokenIdOf(address _address)
        external
        view
        returns (uint256 _tokenId)
    {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        _tokenId = 0;

        for (uint256 i = 1; i <= BonfireStruct.mintIndex; i++) {
            if (BonfireStruct.owners[i] == _address) {
                _tokenId = i;
                break;
            }
        }
    }

    function favoOf(address _address) external view returns (uint256) {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        return BonfireStruct.favos[_address];
    }

    function makiOf(address _address) external view returns (uint256) {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        return BonfireStruct.makis[_address];
    }

    function gradeOf(address _address) external view returns (uint256) {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        return BonfireStruct.grades[_address];
    }

    function makiMemoryOf(address _address) external view returns (uint256) {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        return BonfireStruct.makiMemorys[_address];
    }

    function referralOf(address _address) external view returns (uint256) {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        return BonfireStruct.referrals[_address];
    }

    function monthlyDistributedFavoNum() external view returns (uint256) {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        return BonfireStruct.monthlyDistributedFavoNum;
    }

    function referralRate() external view returns (uint8[] memory) {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        return BonfireStruct.referralRate;
    }

    function lastUpdatedMonth() external view returns (uint256) {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        return BonfireStruct.lastUpdatedMonth;
    }

    function sbtPrice(bool isReferral) external view returns (uint256) {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        if (!isReferral) return BonfireStruct.sbtPrice;
        else return BonfireStruct.sbtReferralPrice;
    }

    function mintedTokenNumber() external view returns (uint256) {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        return BonfireStruct.mintIndex;
    }

    // set functions
    function setExecutor(address _newContactOwner) external onlyExecutor {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        BonfireStruct.executor = _newContactOwner;
        emit executorChanged(_newContactOwner);
    }

    function setAdmin(address _admin) external onlyExecutor {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        BonfireStruct.admin = _admin;
        emit adminChanged(_admin);
    }

    function setBaseUri(string memory _newBaseURI) external onlyExecutor {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        BonfireStruct.baseURI = _newBaseURI;
    }

    function setMonthlyDistributedFavoNum(uint16 _monthlyDistributedFavoNum)
        external
        onlyExecutor
    {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        BonfireStruct.monthlyDistributedFavoNum = _monthlyDistributedFavoNum;
    }

    function setGradePriseRates(
        uint8[] memory _referralRate,
        uint8[] memory _skinnftNumRate,
        uint8[] memory _gradeRate
    ) external onlyExecutor {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        uint256 gradeNum = BonfireStruct.gradeNum;
        require(_referralRate.length == gradeNum, "INVALID LENGTH");
        require(_skinnftNumRate.length == gradeNum, "INVALID LENGTH");
        require(_gradeRate.length == gradeNum, "INVALID LENGTH");
        for (uint256 i = 0; i < gradeNum; i++) {
            BonfireStruct.referralRate[i] = _referralRate[i]; // referal rate. grade 1, 2, 3, 4, 5
            BonfireStruct.skinnftNumRate[i] = _skinnftNumRate[i]; // allocated skinnft for each grade. grade 1, 2, 3, 4, 5
            BonfireStruct.gradeRate[i] = _gradeRate[i]; // percentage of each grade. grade 1, 2, 3, 4, 5
        }
    }

    function setBonfirePrice(
        uint256 _sbtPrice,
        uint256 _sbtReferralPrice,
        uint256 _sbtReferralIncentive
    ) external onlyExecutor {
        require(
            _sbtReferralPrice >= _sbtReferralIncentive,
            "REFERRAL PRICE MUST BE BIGGER THAN REFERRAL INCENTIVE"
        );
        require(
            _sbtPrice >= _sbtReferralPrice,
            "SBT PRICE MUST BE BIGGER THAN REFERRAL PRICE"
        );
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        BonfireStruct.sbtPrice = _sbtPrice;
        BonfireStruct.sbtReferralPrice = _sbtReferralPrice;
        BonfireStruct.sbtReferralIncentive = _sbtReferralIncentive;
    }

    // basic functions for skinnft
    function setSkinnftBaseURI(string memory _newSkinnftBaseURI)
        external
        onlyExecutor
    {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        ISkinNft(BonfireStruct.nftAddress).setBaseURI(_newSkinnftBaseURI);
    }

    // basic functions for skinnft
    function transferEthSkinnft2Bonfire() external {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        require(msg.sender == BonfireStruct.admin, "ADMIN ONLY");
        ISkinNft(BonfireStruct.nftAddress).withdraw();
    }

    // utility function
    function _toString(uint256 value) internal pure returns (string memory) {
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
                // 48 は0のascii値
                buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
                value /= 10;
            }
        }
        return string(buffer);
    }

    fallback() external payable {
        address _imp = implementations[msg.sig];
        require(_imp != address(0), "Function does not exist");
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), _imp, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    function withdraw(uint256 balance) external {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        require(msg.sender == BonfireStruct.admin, "ADMIN ONLY");
        payable(msg.sender).call{value: balance}("");
    }

    receive() external payable {}
}
