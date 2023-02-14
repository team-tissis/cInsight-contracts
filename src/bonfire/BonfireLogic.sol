// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./../libs/BonfireLib.sol";
import "./../libs/DateTime.sol";
import "./../skinnft/ISkinNft.sol";

contract BonfireLogic {
    modifier onlyExecutor() {
        BonfireLib.BonfireStruct storage bs = BonfireLib.bonfireStorage();
        require(msg.sender == bs.executor, "EXECUTOR ONLY");
        _;
    }

    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId
    );

    function mint() public payable returns (uint256) {
        BonfireLib.BonfireStruct storage bs = BonfireLib.bonfireStorage();
        require(msg.value >= bs.sbtPrice, "Need to send more ETH.");
        require(msg.sender != address(0));
        require(bs.grades[msg.sender] == 0, "ALREADY MINTED");
        bs.mintIndex++;
        bs.owners[bs.mintIndex] = msg.sender;
        bs.grades[msg.sender] = 1;
        if (msg.value > bs.sbtPrice) {
            payable(msg.sender).call{value: msg.value - bs.sbtPrice}("");
        }
        emit Transfer(address(0), msg.sender, bs.mintIndex);
        return bs.mintIndex;
    }

    function mintWithReferral(address referrer)
        public
        payable
        returns (uint256)
    {
        BonfireLib.BonfireStruct storage bs = BonfireLib.bonfireStorage();
        require(bs.grades[msg.sender] == 0, "ALREADY MINTED");
        require(msg.value >= bs.sbtReferralPrice, "Need to send more ETH.");

        require(bs.referralMap[msg.sender] == referrer, "INVALID ACCOUNT");

        bs.mintIndex += 1;
        bs.owners[bs.mintIndex] = msg.sender;
        bs.grades[msg.sender] = 1;
        payable(referrer).call{value: bs.sbtReferralIncentive}("");

        if (msg.value > bs.sbtReferralPrice) {
            payable(msg.sender).call{value: msg.value - bs.sbtReferralPrice}(
                ""
            );
        }
        emit Transfer(address(0), msg.sender, bs.mintIndex);

        // referral incentive
        bs.makiMemorys[referrer] += bs.referralSuccessIncentive;
        return bs.mintIndex;
    }

    // set functions

    function burn(uint256 _tokenId) external {
        BonfireLib.BonfireStruct storage bs = BonfireLib.bonfireStorage();
        require(msg.sender == bs.owners[_tokenId], "SBT OWNER ONLY");
        address currentOwner = bs.owners[_tokenId];

        delete bs.owners[_tokenId];
        bs.grades[msg.sender] = 0;
        bs.favos[msg.sender] = 0;
        bs.makiMemorys[msg.sender] = 0;
        bs.makis[msg.sender] = 0;
        bs.referrals[msg.sender] = 0;
        bs.burnNum += 1;

        emit Transfer(currentOwner, address(0), _tokenId);
    }

    function setFreemintQuantity(address _address, uint256 quantity) public {
        BonfireLib.BonfireStruct storage bs = BonfireLib.bonfireStorage();
        require(msg.sender == bs.executor, "ONLY EXECUTOR CAN SET FREEMINT");
        ISkinNft(bs.nftAddress).setFreemintQuantity(_address, quantity);
    }

    function monthInit() public {
        BonfireLib.BonfireStruct storage bs = BonfireLib.bonfireStorage();
        // require(
        //     DateTime.getMonth(block.timestamp) != bs.lastUpdatedMonth,
        //     "monthInit is already executed for this month"
        // );

        _updatemaki(bs);
        _updateGrade(bs);
        // burn されたアカウントも代入計算を行なっている．
        // TODO: sstore 0->0 はガス代がかなり安いらしいが，より良い実装はありうる．
    }

    function _updatemaki(BonfireLib.BonfireStruct storage bs) internal {
        for (uint256 i = 1; i <= bs.mintIndex; i++) {
            address _address = bs.owners[i];
            bs.makis[_address] =
                bs.makiMemorys[_address] +
                (bs.makis[_address] * bs.makiDecayRate) /
                100;
            bs.makiMemorys[_address] = 0;
            if (bs.favos[_address] == bs.monthlyDistributedFavoNum) {
                bs.makis[_address] += bs.favoUseUpIncentive;
            }
        }
    }

    function _updateGrade(BonfireLib.BonfireStruct storage bs) internal {
        uint256 accountNum = bs.mintIndex - bs.burnNum;
        uint256 gradeNum = bs.gradeNum;
        uint16[] memory makiSortedIndex = new uint16[](accountNum);
        uint32[] memory makiArray = new uint32[](accountNum);
        uint256[] memory gradeThreshold = new uint256[](gradeNum);

        uint256 count;
        uint256 j;
        for (uint256 i = 1; i <= bs.mintIndex; i++) {
            address _address = bs.owners[i];
            if (_address != address(0)) {
                makiSortedIndex[count] = uint16(i);
                makiArray[count] = uint32(bs.makis[_address]);
                count += 1;
            }
        }
        _quickSort(
            makiArray,
            makiSortedIndex,
            int256(0),
            int256(accountNum - 1)
        );
        gradeNum--;
        for (j = 0; j < gradeNum; j++) {
            gradeThreshold[j] = accountNum * bs.gradeRate[j];
        }
        uint256 grade;
        uint256 skinnftQuantity;
        // burnされていない account 中の上位 x %を計算.
        for (uint256 i = 0; i < accountNum; i++) {
            address _address = bs.owners[makiSortedIndex[i]];
            grade = 1;
            for (j = 0; j < gradeNum; j++) {
                if (i * 100 >= gradeThreshold[j]) {
                    break;
                }
                grade++;
                // set grade
            }
            bs.grades[_address] = grade;
            // set skin nft freemint
            skinnftQuantity = bs.skinnftNumRate[grade - 1];
            if (skinnftQuantity > 0) {
                ISkinNft(bs.nftAddress).setFreemintQuantity(
                    _address,
                    skinnftQuantity
                );
            }

            // initialize referral and favos

            bs.favos[_address] = 0;
            bs.referrals[_address] = 0;
        }
    }

    // functions for frontend
    function addFavos(address userTo, uint8 favo) external {
        require(favo > 0, "favo num must be bigger than 0");

        BonfireLib.BonfireStruct storage bs = BonfireLib.bonfireStorage();
        require(bs.grades[msg.sender] != 0, "SENDER: SBT HOLDER ONLY");
        require(bs.grades[userTo] != 0, "USERTO: SBT HOLDER ONLY");
        require(msg.sender != userTo, "CAN'T FAVO YOURSELF");

        uint256 addmonthlyDistributedFavoNum;
        require(
            bs.monthlyDistributedFavoNum > bs.favos[msg.sender],
            "INVALID ARGUMENT"
        );
        uint256 remainFavo = bs.monthlyDistributedFavoNum -
            bs.favos[msg.sender];

        // 付与するfavoが残りfavo数より大きい場合は，残りfavoを全て付与する．
        if (remainFavo <= favo) {
            addmonthlyDistributedFavoNum = remainFavo;
        } else {
            addmonthlyDistributedFavoNum = favo;
        }

        bs.favos[msg.sender] += addmonthlyDistributedFavoNum;

        // makiMemoryの計算
        uint256 upperBound = 5;
        (uint256 _dist, bool connectFlag) = _distance(msg.sender, userTo);

        if (connectFlag && _dist < upperBound) {
            bs.makiMemorys[userTo] += _dist * addmonthlyDistributedFavoNum;
        } else {
            bs.makiMemorys[userTo] += upperBound * addmonthlyDistributedFavoNum;
        }
    }

    function _distance(address node1, address node2)
        internal
        view
        returns (uint256, bool)
    {
        BonfireLib.BonfireStruct storage bs = BonfireLib.bonfireStorage();

        uint256 _dist1;
        uint256 _dist2;
        address _node1;
        address _node2;
        bool connectFlag = false;

        _node1 = node1;
        while (_node1 != address(0)) {
            if (_node1 == node2) {
                connectFlag = true;
                break;
            }
            _node2 = bs.referralMap[node2];
            while (_node2 != address(0)) {
                _dist2 += 1;
                if (_node1 == _node2) {
                    connectFlag = true;
                    break;
                }
                _node2 = bs.referralMap[_node2];
            }
            _node1 = bs.referralMap[_node1];
            _dist1 += 1;
            _dist2 = 0;
        }
        return (_dist1 + _dist2, connectFlag);
    }

    function refer(address userTo) external {
        BonfireLib.BonfireStruct storage bs = BonfireLib.bonfireStorage();
        require(bs.grades[userTo] == 0, "ALREADY MINTED");
        require(
            bs.referralMap[userTo] == address(0),
            "THIS USER HAS ALREADY REFERRED"
        );
        require(
            bs.grades[msg.sender] >= 1 &&
                bs.referrals[msg.sender] <
                bs.referralRate[bs.grades[msg.sender] - 1],
            "REFER LIMIT EXCEEDED"
        );
        bs.referralMap[userTo] = msg.sender;
        bs.referrals[msg.sender] += 1;
    }

    // descending
    function _quickSort(
        uint32[] memory arr,
        uint16[] memory ind,
        int256 left,
        int256 right
    ) internal {
        int256 i = left;
        int256 j = right;
        if (i == j) return;
        uint256 pivot = arr[uint256(left + (right - left) / 2)];
        while (i <= j) {
            while (arr[uint256(i)] > pivot) i++;
            while (pivot > arr[uint256(j)]) j--;
            if (i <= j) {
                (arr[uint256(i)], arr[uint256(j)]) = (
                    arr[uint256(j)],
                    arr[uint256(i)]
                );
                (ind[uint256(i)], ind[uint256(j)]) = (
                    ind[uint256(j)],
                    ind[uint256(i)]
                );
                i++;
                j--;
            }
        }
        if (left < j) _quickSort(arr, ind, left, j);
        if (i < right) _quickSort(arr, ind, i, right);
    }
}
