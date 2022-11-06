// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./../libs/BonfireLib.sol";
import "./../libs/DateTime.sol";
import "./../skinnft/ISkinNft.sol";

contract BonfireImp {
    modifier onlyExecutor() {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        require(msg.sender == BonfireStruct.executor, "EXECUTOR ONLY");
        _;
    }

    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId
    );

    function mint() public payable returns (uint256) {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        require(msg.value >= BonfireStruct.sbtPrice, "Need to send more ETH.");
        require(msg.sender != address(0));
        require(BonfireStruct.grades[msg.sender] == 0, "ALREADY MINTED");
        BonfireStruct.mintIndex++;
        BonfireStruct.owners[BonfireStruct.mintIndex] = msg.sender;
        BonfireStruct.grades[msg.sender] = 1;
        if (msg.value > BonfireStruct.sbtPrice) {
            payable(msg.sender).call{value: msg.value - BonfireStruct.sbtPrice}(
                ""
            );
        }
        emit Transfer(address(0), msg.sender, BonfireStruct.mintIndex);
        return BonfireStruct.mintIndex;
    }

    function mintWithReferral(address referrer)
        public
        payable
        returns (uint256)
    {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        require(BonfireStruct.grades[msg.sender] == 0, "ALREADY MINTED");
        require(
            msg.value >= BonfireStruct.sbtReferralPrice,
            "Need to send more ETH."
        );

        require(
            BonfireStruct.referralMap[msg.sender] == referrer,
            "INVALID ACCOUNT"
        );

        BonfireStruct.mintIndex += 1;
        BonfireStruct.owners[BonfireStruct.mintIndex] = msg.sender;
        BonfireStruct.grades[msg.sender] = 1;
        payable(referrer).call{value: BonfireStruct.sbtReferralIncentive}("");

        if (msg.value > BonfireStruct.sbtReferralPrice) {
            payable(msg.sender).call{
                value: msg.value - BonfireStruct.sbtReferralPrice
            }("");
        }
        emit Transfer(address(0), msg.sender, BonfireStruct.mintIndex);
        return BonfireStruct.mintIndex;
    }

    // set functions

    function burn(uint256 _tokenId) external {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        require(msg.sender == BonfireStruct.owners[_tokenId], "SBT OWNER ONLY");
        address currentOwner = BonfireStruct.owners[_tokenId];

        delete BonfireStruct.owners[_tokenId];
        BonfireStruct.grades[msg.sender] = 0;
        BonfireStruct.favos[msg.sender] = 0;
        BonfireStruct.makiMemorys[msg.sender] = 0;
        BonfireStruct.makis[msg.sender] = 0;
        BonfireStruct.referrals[msg.sender] = 0;
        BonfireStruct.burnNum += 1;

        emit Transfer(currentOwner, address(0), _tokenId);
    }

    function setFreemintQuantity(address _address, uint256 quantity) public {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        require(
            msg.sender == BonfireStruct.executor,
            "ONLY EXECUTOR CAN SET FREEMINT"
        );
        ISkinNft(BonfireStruct.nftAddress).setFreemintQuantity(
            _address,
            quantity
        );
    }

    function monthInit() public {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        require(
            DateTime.getMonth(block.timestamp) !=
                BonfireStruct.lastUpdatedMonth,
            "monthInit is already executed for this month"
        );

        _updatemaki(BonfireStruct);
        _updateGrade(BonfireStruct);
        // burn されたアカウントも代入計算を行なっている．
        // TODO: sstore 0->0 はガス代がかなり安いらしいが，より良い実装はありうる．
    }

    function _updatemaki(BonfireLib.BonfireStruct storage BonfireStruct)
        internal
    {
        for (uint256 i = 1; i <= BonfireStruct.mintIndex; i++) {
            address _address = BonfireStruct.owners[i];
            BonfireStruct.makis[_address] =
                BonfireStruct.makiMemorys[_address] +
                (BonfireStruct.makis[_address] * BonfireStruct.makiDecayRate) /
                100;
            BonfireStruct.makiMemorys[_address] = 0;
            if (
                BonfireStruct.favos[_address] ==
                BonfireStruct.monthlyDistributedFavoNum
            ) {
                BonfireStruct.makis[_address] += BonfireStruct
                    .favoUseUpIncentive;
            }
        }
    }

    function _updateGrade(BonfireLib.BonfireStruct storage BonfireStruct)
        internal
    {
        uint256 accountNum = BonfireStruct.mintIndex - BonfireStruct.burnNum;
        uint256 gradeNum = BonfireStruct.gradeNum;
        uint16[] memory makiSortedIndex = new uint16[](accountNum);
        uint32[] memory makiArray = new uint32[](accountNum);
        uint256[] memory gradeThreshold = new uint256[](gradeNum);

        uint256 count;
        uint256 j;
        for (uint256 i = 1; i <= BonfireStruct.mintIndex; i++) {
            address _address = BonfireStruct.owners[i];
            if (_address != address(0)) {
                makiSortedIndex[count] = uint16(i);
                makiArray[count] = uint32(BonfireStruct.makis[_address]);
                count += 1;
            }
        }
        _quickSort(makiArray, makiSortedIndex, int(0), int(accountNum - 1));
        gradeNum--;
        for (j = 0; j < gradeNum; j++) {
            gradeThreshold[j] = accountNum * BonfireStruct.gradeRate[j];
        }
        uint256 grade;
        uint256 skinnftQuantity;
        // burnされていない account 中の上位 x %を計算.
        for (uint256 i = 0; i < accountNum; i++) {
            address _address = BonfireStruct.owners[makiSortedIndex[i]];
            grade = 1;
            for (j = 0; j < gradeNum; j++) {
                if (i * 100 >= gradeThreshold[j]) {
                    break;
                }
                grade++;
                // set grade
            }
            BonfireStruct.grades[_address] = grade;
            // set skin nft freemint
            skinnftQuantity = BonfireStruct.skinnftNumRate[grade - 1];
            if (skinnftQuantity > 0) {
                ISkinNft(BonfireStruct.nftAddress).setFreemintQuantity(
                    _address,
                    skinnftQuantity
                );
            }

            // initialize referral and favos

            BonfireStruct.favos[_address] = 0;
            BonfireStruct.referrals[_address] = 0;
        }
    }

    // functions for frontend
    function addFavos(address userTo, uint8 favo) external {
        require(favo > 0, "favo num must be bigger than 0");

        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        require(
            BonfireStruct.grades[msg.sender] != 0,
            "SENDER: SBT HOLDER ONLY"
        );
        require(BonfireStruct.grades[userTo] != 0, "USERTO: SBT HOLDER ONLY");
        require(msg.sender != userTo, "CAN'T FAVO YOURSELF");

        uint256 addmonthlyDistributedFavoNum;
        require(
            BonfireStruct.monthlyDistributedFavoNum >
                BonfireStruct.favos[msg.sender],
            "INVALID ARGUMENT"
        );
        uint256 remainFavo = BonfireStruct.monthlyDistributedFavoNum -
            BonfireStruct.favos[msg.sender];

        // 付与するfavoが残りfavo数より大きい場合は，残りfavoを全て付与する．
        if (remainFavo <= favo) {
            addmonthlyDistributedFavoNum = remainFavo;
        } else {
            addmonthlyDistributedFavoNum = favo;
        }

        BonfireStruct.favos[msg.sender] += addmonthlyDistributedFavoNum;

        // makiMemoryの計算
        uint256 upperBound = 5;
        (uint256 _dist, bool connectFlag) = _distance(msg.sender, userTo);

        if (connectFlag && _dist < upperBound) {
            BonfireStruct.makiMemorys[userTo] +=
                _dist *
                addmonthlyDistributedFavoNum;
        } else {
            BonfireStruct.makiMemorys[userTo] +=
                upperBound *
                addmonthlyDistributedFavoNum;
        }
    }

    function _distance(address node1, address node2)
        internal
        view
        returns (uint256, bool)
    {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();

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
            _node2 = BonfireStruct.referralMap[node2];
            while (_node2 != address(0)) {
                _dist2 += 1;
                if (_node1 == _node2) {
                    connectFlag = true;
                    break;
                }
                _node2 = BonfireStruct.referralMap[_node2];
            }
            _node1 = BonfireStruct.referralMap[_node1];
            _dist1 += 1;
            _dist2 = 0;
        }
        return (_dist1 + _dist2, connectFlag);
    }

    function refer(address userTo) external {
        BonfireLib.BonfireStruct storage BonfireStruct = BonfireLib
            .bonfireStorage();
        require(BonfireStruct.grades[userTo] == 0, "ALREADY MINTED");
        require(
            BonfireStruct.referralMap[userTo] == address(0),
            "THIS USER HAS ALREADY REFERRED"
        );
        require(
            BonfireStruct.grades[msg.sender] >= 1 &&
                BonfireStruct.referrals[msg.sender] <
                BonfireStruct.referralRate[
                    BonfireStruct.grades[msg.sender] - 1
                ],
            "REFER LIMIT EXCEEDED"
        );
        BonfireStruct.referralMap[userTo] = msg.sender;
        BonfireStruct.referrals[msg.sender] += 1;
    }

    // descending
    function _quickSort(
        uint32[] memory arr,
        uint16[] memory ind,
        int left,
        int right
    ) internal {
        int i = left;
        int j = right;
        if (i == j) return;
        uint pivot = arr[uint(left + (right - left) / 2)];
        while (i <= j) {
            while (arr[uint(i)] > pivot) i++;
            while (pivot > arr[uint(j)]) j--;
            if (i <= j) {
                (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
                (ind[uint(i)], ind[uint(j)]) = (ind[uint(j)], ind[uint(i)]);
                i++;
                j--;
            }
        }
        if (left < j) _quickSort(arr, ind, left, j);
        if (i < right) _quickSort(arr, ind, i, right);
    }
}
