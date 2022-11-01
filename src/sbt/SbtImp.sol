// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./../libs/SbtLib.sol";
import "./../libs/DateTime.sol";
import "./../libs/QuickSort.sol";
import "./../skinnft/ISkinNft.sol";
import "forge-std/Test.sol";

contract SbtImp {
    modifier onlyAdmin() {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(msg.sender == sbtstruct.admin, "OWNER ONLY");
        _;
    }

    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId
    );

    function mint() public payable returns (uint256) {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(msg.value >= sbtstruct.sbtPrice, "Need to send more ETH.");
        require(msg.sender != address(0));
        require(sbtstruct.grades[msg.sender] == 0, "ALREADY MINTED");
        sbtstruct.mintIndex += 1;
        sbtstruct.owners[sbtstruct.mintIndex] = msg.sender;
        sbtstruct.grades[msg.sender] = 1;
        if (msg.value > sbtstruct.sbtPrice) {
            payable(msg.sender).call{value: msg.value - sbtstruct.sbtPrice}("");
        }
        emit Transfer(address(0), msg.sender, sbtstruct.mintIndex);
        return sbtstruct.mintIndex;
    }

    function mintWithReferral(address referrer) public payable {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(sbtstruct.grades[msg.sender] == 0, "ALREADY MINTED");
        require(
            msg.value >= sbtstruct.sbtReferralPrice,
            "Need to send more ETH."
        );

        require(
            sbtstruct.referralMap[msg.sender] == referrer,
            "INVALID ACCOUNT"
        );

        sbtstruct.mintIndex += 1;
        sbtstruct.owners[sbtstruct.mintIndex] = msg.sender;
        sbtstruct.grades[msg.sender] = 1;
        payable(referrer).call{value: sbtstruct.sbtReferralIncentive}("");

        if (msg.value > sbtstruct.sbtReferralPrice) {
            payable(msg.sender).call{
                value: msg.value - sbtstruct.sbtReferralPrice
            }("");
        }
        emit Transfer(address(0), msg.sender, sbtstruct.mintIndex);
    }

    // set functions

    function burn(uint _tokenId) external {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(msg.sender == sbtstruct.owners[_tokenId], "SBT OWNER ONLY");
        address currentOwner = sbtstruct.owners[_tokenId];

        delete sbtstruct.owners[_tokenId];
        sbtstruct.grades[msg.sender] = 0;
        sbtstruct.favos[msg.sender] = 0;
        sbtstruct.makiMemorys[msg.sender] = 0;
        sbtstruct.makis[msg.sender] = 0;
        sbtstruct.referrals[msg.sender] = 0;
        sbtstruct.burnNum += 1;

        emit Transfer(currentOwner, address(0), _tokenId);
    }

    function setFreemintQuantity(address _address, uint256 quantity) public {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(msg.sender == sbtstruct.admin, "ONLY ADMIN CAN SET FREEMINT");
        ISkinNft(sbtstruct.nftAddress).setFreemintQuantity(_address, quantity);
    }

    function monthInit() public {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(
            DateTime.getMonth(block.timestamp) != sbtstruct.lastUpdatedMonth,
            "monthInit is already executed for this month"
        );

        _updatemaki(sbtstruct);
        _updateGrade(sbtstruct);
        // burn されたアカウントも代入計算を行なっている．
        // TODO: sstore 0->0 はガス代がかなり安いらしいが，より良い実装はありうる．
    }

    function _updatemaki(SbtLib.SbtStruct storage sbtstruct) internal {
        for (uint i = 1; i <= sbtstruct.mintIndex; i++) {
            address _address = sbtstruct.owners[i];
            sbtstruct.makis[_address] =
                sbtstruct.makiMemorys[_address] +
                (sbtstruct.makis[_address] * sbtstruct.makiDecayRate) /
                100;
            if (
                sbtstruct.favos[_address] == sbtstruct.monthlyDistributedFavoNum
            ) {
                sbtstruct.makis[_address] += sbtstruct.favoUseUpIncentive;
            }
        }
    }

    function _updateGrade(SbtLib.SbtStruct storage sbtstruct) internal {
        uint accountNum = sbtstruct.mintIndex - sbtstruct.burnNum;
        uint gradeNum = sbtstruct.gradeNum;
        uint16[] memory makiSortedIndex = new uint16[](accountNum);
        uint32[] memory makiArray = new uint32[](accountNum);
        uint256[] memory gradeThreshold = new uint256[](gradeNum);

        uint count;
        uint j;
        for (uint i = 1; i <= sbtstruct.mintIndex; i++) {
            address _address = sbtstruct.owners[i];
            if (_address != address(0)) {
                makiSortedIndex[count] = uint16(i);
                makiArray[count] = uint32(sbtstruct.makis[_address]);
                count += 1;
            }
        }
        makiSortedIndex = QuickSort.sort(makiArray, makiSortedIndex);
        gradeNum--;
        for (j = 0; j < gradeNum; j++) {
            gradeThreshold[j] = accountNum * sbtstruct.gradeRate[j];
        }
        uint256 tmp_count;
        // burnされていない account 中の上位 x %を計算.
        for (uint i = 0; i < accountNum; i++) {
            address _address = sbtstruct.owners[makiSortedIndex[i]];
            tmp_count = 1;
            for (uint j = 0; j < gradeNum; j++) {
                if (i * 100 >= gradeThreshold[j]) {
                    break;
                }
                tmp_count++;
                // set grade
                sbtstruct.grades[_address] = j + 2;
                // set skin nft freemint
                ISkinNft(sbtstruct.nftAddress).setFreemintQuantity(
                    _address,
                    sbtstruct.skinnftNumRate[j + 1]
                );
                // initialize referral and favos
            }
            sbtstruct.favos[_address] = 0;
            sbtstruct.referrals[_address] = 0;
        }
    }

    // functions for frontend
    function addFavos(address userTo, uint8 favo) external {
        require(favo > 0, "favo num must be bigger than 0");

        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(sbtstruct.grades[msg.sender] != 0, "SBT HOLDER ONLY");

        uint addmonthlyDistributedFavoNum;
        require(
            sbtstruct.monthlyDistributedFavoNum > sbtstruct.favos[msg.sender],
            "INVALID ARGUMENT"
        );
        uint remainFavo = sbtstruct.monthlyDistributedFavoNum -
            sbtstruct.favos[msg.sender];

        // 付与するfavoが残りfavo数より大きい場合は，残りfavoを全て付与する．
        if (remainFavo <= favo) {
            addmonthlyDistributedFavoNum = remainFavo;
        } else {
            addmonthlyDistributedFavoNum = favo;
        }

        sbtstruct.favos[msg.sender] += addmonthlyDistributedFavoNum;

        // makiMemoryの計算
        uint upperBound = 5;
        (uint _dist, bool connectFlag) = _distance(msg.sender, userTo);

        if (connectFlag && _dist < upperBound) {
            sbtstruct.makiMemorys[userTo] =
                _dist *
                addmonthlyDistributedFavoNum;
        } else {
            sbtstruct.makiMemorys[userTo] =
                upperBound *
                addmonthlyDistributedFavoNum;
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
            "THIS USER HAS ALREADY REFERRED"
        );
        require(
            sbtstruct.grades[msg.sender] >= 1 &&
                sbtstruct.referrals[msg.sender] <
                sbtstruct.referralRate[sbtstruct.grades[msg.sender] - 1],
            "REFER LIMIT EXCEEDED"
        );
        sbtstruct.referralMap[userTo] = msg.sender;
        sbtstruct.referrals[msg.sender] += 1;
    }
}
