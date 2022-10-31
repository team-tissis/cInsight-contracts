// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./../libs/SbtLib.sol";
import "./../libs/DateTime.sol";
import "./../libs/QuickSort.sol";
import "./../skinnft/ISkinNft.sol";

contract SbtImp {
    modifier onlyOwner() {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(msg.sender == sbtstruct.admin, "OWNER ONLY");
        _;
    }

    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId
    );

    function mint() public payable {
        require(msg.sender != address(0));
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();

        require(sbtstruct.grades[msg.sender] == 0, "ALREADY MINTED");
        _mint(sbtstruct);
        emit Transfer(address(0), msg.sender, sbtstruct.mintIndex);
    }

    function mintWithReferral(address referrer) public payable {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(sbtstruct.grades[msg.sender] == 0, "ALREADY MINTED");
        _mintWithReferral(sbtstruct, referrer);
        emit Transfer(address(0), msg.sender, sbtstruct.mintIndex);
    }

    function _mint(SbtLib.SbtStruct storage sbtstruct) internal {
        uint costForMint = 20 ether;
        require(msg.value >= costForMint, "Need to send more ETH.");

        sbtstruct.mintIndex += 1;
        sbtstruct.owners[sbtstruct.mintIndex] = msg.sender;
        sbtstruct.grades[msg.sender] = 1;

        if (msg.value > costForMint) {
            payable(msg.sender).transfer(msg.value - costForMint);
        }
    }

    function _mintWithReferral(
        SbtLib.SbtStruct storage sbtstruct,
        address referrer
    ) internal {
        uint costForMint = 15 ether;
        uint incentiveForReferrer = 10 ether;
        require(msg.value >= costForMint, "Need to send more ETH.");

        require(
            sbtstruct.referralMap[msg.sender] == referrer,
            "INVALID ACCOUNT"
        );

        sbtstruct.mintIndex += 1;
        sbtstruct.owners[sbtstruct.mintIndex] = msg.sender;
        sbtstruct.grades[msg.sender] = 1;

        payable(referrer).transfer(incentiveForReferrer);

        if (msg.value > costForMint) {
            payable(msg.sender).transfer(msg.value - costForMint);
        }
    }

    function burn(uint _tokenId) external {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(msg.sender == sbtstruct.owners[_tokenId], "SBT OWNER ONLY");
        address currentOwner = sbtstruct.owners[_tokenId];

        delete sbtstruct.owners[_tokenId];
        sbtstruct.grades[msg.sender] = 0;
        sbtstruct.favos[msg.sender] = 0;
        sbtstruct.makis[msg.sender] = 0;
        sbtstruct.rates[msg.sender] = 0;
        sbtstruct.referrals[msg.sender] = 0;
        sbtstruct.nftPoints[msg.sender] = 0;
        sbtstruct.burnNum += 1;

        emit Transfer(currentOwner, address(0), _tokenId);
    }

    function setFreemintQuantity(address _address, uint256 quantity) public {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(msg.sender == sbtstruct.admin, "ONLY ADMIN CAN SET FREEMINT");
        ISkinNft(sbtstruct.nftAddress).setFreemintQuantity(_address, quantity);
    }

    // chaininsight functions
    function impInit() external onlyOwner {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        sbtstruct.favoNum = 20;
        sbtstruct.lastUpdatedMonth = uint8(DateTime.getMonth(block.timestamp));
        uint8[5] memory _referralRate = [0, 0, 1, 3, 5]; // grade 1,2,3,4,5
        uint8[5] memory _nftNumRate = [0, 0, 0, 1, 2]; // grade 1,2,3,4,5
        for (uint i = 0; i < 5; i++) {
            sbtstruct.referralRate.push(_referralRate[i]);
            sbtstruct.nftNumRate.push(_nftNumRate[i]);
        }
    }

    function monthInit() public {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(
            DateTime.getMonth(block.timestamp) != sbtstruct.lastUpdatedMonth
        );

        _addMakiForDoneFavo(sbtstruct);
        _updateRate(sbtstruct);
        _updateGrade(sbtstruct);

        // burn されたアカウントも代入計算を行なっている．
        // TODO: sstore 0->0 はガス代がかなり安いらしいが，より良い実装はありうる．
        for (uint i = 1; i <= sbtstruct.mintIndex; i++) {
            address _address = sbtstruct.owners[i]; //TODO: このようにmemoryに一時保存すると安い？
            sbtstruct.favos[_address] = 0;
            sbtstruct.referrals[_address] = 0;
        }
    }

    function _addMakiForDoneFavo(SbtLib.SbtStruct storage sbtstruct) internal {
        for (uint i = 1; i <= sbtstruct.mintIndex; i++) {
            address _address = sbtstruct.owners[i]; //TODO: このようにmemoryに一時保存すると安い？

            if (sbtstruct.favos[_address] == sbtstruct.favoNum) {
                sbtstruct.makis[_address] += 10;
            }
        }
    }

    function _updateRate(SbtLib.SbtStruct storage sbtstruct) internal {
        for (uint i = 1; i <= sbtstruct.mintIndex; i++) {
            address _address = sbtstruct.owners[i];

            sbtstruct.rates[_address] =
                sbtstruct.makis[_address] +
                sbtstruct.rates[_address] /
                4;
        }
    }

    function _updateGrade(SbtLib.SbtStruct storage sbtstruct) internal {
        uint accountNum = sbtstruct.mintIndex - sbtstruct.burnNum;
        uint16[] memory rateSortedIndex = new uint16[](accountNum);
        uint32[] memory rateArray = new uint32[](accountNum);

        uint count;
        for (uint i = 1; i <= sbtstruct.mintIndex; i++) {
            address _address = sbtstruct.owners[i];
            if (_address != address(0)) {
                count += 1;
                rateSortedIndex[count] = uint16(i);
                rateArray[count] = uint32(sbtstruct.rates[_address]);
            }
        }
        rateSortedIndex = QuickSort.sort(rateArray, rateSortedIndex);

        // burnされていない account 中の上位 x %を計算.
        for (uint i = 0; i < accountNum; i++) {
            address _address = sbtstruct.owners[rateSortedIndex[i]];
            if (i <= accountNum / 20) {
                // 上位 5%
                sbtstruct.grades[_address] = 5;
                ISkinNft(sbtstruct.nftAddress).setFreemintQuantity(_address, 2);
            } else if (i <= accountNum / 5) {
                // 上位 20%
                sbtstruct.grades[_address] = 4;
                ISkinNft(sbtstruct.nftAddress).setFreemintQuantity(_address, 1);
            } else if (i <= (accountNum / 5) * 2) {
                // 上位 40%
                sbtstruct.grades[_address] = 3;
            } else if (i <= (accountNum / 5) * 4) {
                // 上位 80%
                sbtstruct.grades[_address] = 2;
            } else {
                sbtstruct.grades[_address] = 1;
            }
        }
    }

    // functions for frontend
    function addFavos(address userTo, uint8 favo) external {
        require(favo > 0, "INVALID ARGUMENT");

        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(sbtstruct.grades[msg.sender] != 0, "SBT HOLDER ONLY");

        uint addFavoNum;
        uint remainFavo = sbtstruct.favoNum - sbtstruct.favos[msg.sender];
        require(remainFavo >= 0, "INVALID ARGUMENT");

        // 付与するfavoが残りfavo数より大きい場合は，残りfavoを全て付与する．
        if (remainFavo <= favo) {
            addFavoNum = remainFavo;
        } else {
            addFavoNum = favo;
        }

        sbtstruct.favos[msg.sender] = addFavoNum;

        // makiの計算
        uint upperBound = 5;
        (uint _dist, bool connectFlag) = _distance(msg.sender, userTo);

        if (connectFlag && _dist < upperBound) {
            sbtstruct.makis[userTo] = _dist;
        } else {
            sbtstruct.makis[userTo] = upperBound;
        }
    }

    function _distance(address node1, address node2)
        internal
        view
        returns (uint, bool)
    {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();

        uint _dist1;
        uint _dist2;
        bool connectFlag = false;

        while (node1 != address(0)) {
            if (node1 == node2) {
                connectFlag = true;
                break;
            } else {
                while (node2 != address(0)) {
                    node2 = sbtstruct.referralMap[node2];
                    _dist2 += 1;
                    if (node1 == node2) {
                        connectFlag = true;
                        break;
                    }
                }
                node1 = sbtstruct.referralMap[node1];
                _dist1 += 1;
                _dist2 = 0;
            }
        }
        return (_dist1 + _dist2, connectFlag);
    }

    function refer(address userTo) external {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(sbtstruct.grades[userTo] == 0, "ALREADY MINTED");
        require(
            sbtstruct.referralMap[userTo] == address(0),
            "THIS USER HAS ALREADY REFFERD"
        );
        require(
            sbtstruct.referrals[msg.sender] <=
                sbtstruct.referralRate[sbtstruct.grades[msg.sender]],
            "REFFER LIMIT EXCEEDED"
        );
        sbtstruct.referralMap[userTo] = msg.sender;
        sbtstruct.referrals[msg.sender] += 1;
    }
}
