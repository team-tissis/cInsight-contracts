// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./../libs/SbtLib.sol";
import "./ISbt.sol";
import "./../skinnft/ISkinNft.sol";

contract Sbt is ISbt {
    modifier onlyAdmin() {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(msg.sender == sbtstruct.admin, "ADMIN ONLY");
        _;
    }
    event adminChanged(address _newOwner);

    function init(
        address _admin,
        string calldata _name,
        string calldata _symbol,
        string calldata _baseURI,
        address _nftAddress
    ) external {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(_admin != address(0), "_admin must not be address 0");
        require(sbtstruct.admin == address(0), "INITIATED ALREADY");
        sbtstruct.admin = _admin;
        sbtstruct.name = _name;
        sbtstruct.symbol = _symbol;
        sbtstruct.baseURI = _baseURI;
        sbtstruct.nftAddress = _nftAddress;
        sbtstruct.interfaces[(bytes4)(0x01ffc9a7)] = true; //ERC165
        sbtstruct.interfaces[(bytes4)(0x5b5e139f)] = true; //ERC721metadata
        sbtstruct.sbtPrice = 20 ether;
        sbtstruct.sbtReferralPrice = 15 ether;
        sbtstruct.sbtReferralIncentive = 10 ether;
        sbtstruct.monthlyDistributedFavoNum = 20;
        sbtstruct.lastUpdatedMonth = 0; //initial value for last updated month
        uint8[5] memory _referralRate = [0, 0, 1, 3, 5]; // grade 1,2,3,4,5
        uint8[5] memory _skinnftNumRate = [0, 0, 0, 1, 2]; // grade 1,2,3,4,5
        for (uint i = 0; i < 5; i++) {
            sbtstruct.referralRate.push(_referralRate[i]);
            sbtstruct.skinnftNumRate.push(_skinnftNumRate[i]);
        }
    }

    mapping(bytes4 => address) public implementations;

    // storage type に calldataを用いると変数はimmutableになりガス代節約できる。
    function setImplementation(
        bytes4[] calldata _sigs,
        address[] calldata _impAddress
    ) external {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(msg.sender == sbtstruct.admin, "OWNER ONLY");
        require(_sigs.length == _impAddress.length, "INVALID LENGTH");
        for (uint256 i = 0; i < _sigs.length; i++) {
            unchecked {
                implementations[_sigs[i]] = _impAddress[i];
            }
        }
    }

    // get functions
    function admin() external view returns (address) {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.admin;
    }

    // supportしているERCversionなど
    function supportsInterface(bytes4 _interfaceID)
        external
        view
        returns (bool)
    {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.interfaces[_interfaceID];
    }

    function name() external view returns (string memory) {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.name;
    }

    //0x95d89b41
    function symbol() external view returns (string memory) {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.symbol;
    }

    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return
            string(
                abi.encodePacked(
                    sbtstruct.baseURI,
                    _toString(_tokenId),
                    ".json"
                )
            );
    }

    function ownerOf(uint256 _tokenId) external view returns (address) {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.owners[_tokenId];
    }

    function setadmin(address _newContactOwner) external onlyAdmin {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        sbtstruct.admin = _newContactOwner;
        emit adminChanged(_newContactOwner);
    }

    function favoOf(address _address) external view returns (uint) {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.favos[_address];
    }

    function makiOf(address _address) external view returns (uint) {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.makis[_address];
    }

    function gradeOf(address _address) external view returns (uint) {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.grades[_address];
    }

    function makiMemoryOf(address _address) external view returns (uint) {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.makiMemorys[_address];
    }

    function referralOf(address _address) external view returns (uint) {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.referrals[_address];
    }

    function monthlyDistributedFavoNum() external view returns (uint) {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.monthlyDistributedFavoNum;
    }

    function referralRate() external view returns (uint8[] memory) {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.referralRate;
    }

    function lastUpdatedMonth() external view returns (uint) {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.lastUpdatedMonth;
    }

    function sbtPrice(bool isReferral) external view returns (uint256) {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        if (!isReferral) return sbtstruct.sbtPrice;
        else return sbtstruct.sbtReferralPrice;
    }

    // set functions

    function setBaseUri(string memory _newBaseURI) external onlyAdmin {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        sbtstruct.baseURI = _newBaseURI;
    }

    function setMonthlyDistributedFavoNum(uint16 _monthlyDistributedFavoNum)
        external
        onlyAdmin
    {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        sbtstruct.monthlyDistributedFavoNum = _monthlyDistributedFavoNum;
    }

    function setGradePriseRates(
        uint8[] memory _referralRate,
        uint8[] memory _skinnftNumRate,
        uint8[] memory _gradeRate
    ) external onlyAdmin {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        uint256 gradeNum = sbtstruct.gradeNum;
        require(_referralRate.length == gradeNum, "INVALID LENGTH");
        require(_skinnftNumRate.length == gradeNum, "INVALID LENGTH");
        require(_gradeRate.length == gradeNum, "INVALID LENGTH");
        for (uint256 i = 0; i < gradeNum; i++) {
            sbtstruct.referralRate[i] = _referralRate[i]; // referal rate. grade 1, 2, 3, 4, 5
            sbtstruct.skinnftNumRate[i] = _skinnftNumRate[i]; // allocated skinnft for each grade. grade 1, 2, 3, 4, 5
            sbtstruct.gradeRate[i] = _gradeRate[i]; // percentage of each grade. grade 1, 2, 3, 4, 5
        }
    }

    function setSbtPrice(
        uint256 _sbtPrice,
        uint256 _sbtReferralPrice,
        uint256 _sbtReferralIncentive
    ) external onlyAdmin {
        require(
            _sbtReferralPrice >= _sbtReferralIncentive,
            "REFERRAL PRICE MUST BE BIGGER THAN REFERRAL INCENTIVE"
        );
        require(
            _sbtPrice >= _sbtReferralPrice,
            "SBT PRICE MUST BE BIGGER THAN REFERRAL PRICE"
        );
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        sbtstruct.sbtPrice = _sbtPrice;
        sbtstruct.sbtReferralPrice = _sbtReferralPrice;
        sbtstruct.sbtReferralIncentive = _sbtReferralIncentive;
    }

    // utility function from openzeppelin
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

    function transferEth(uint256 ethValue, address _address) external {
        require(
            msg.sender == address(this),
            "MSG sender must be this contract"
        );
        payable(_address).call{value: ethValue}("");
    }

    receive() external payable {}
}
