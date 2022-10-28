// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./../libs/SbtLib.sol";
import "./../libs/DateTime.sol";
import "./../libs/QuickSort.sol";

contract SbtImp {
    modifier onlyOwner() {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(msg.sender == sbtstruct.contractOwner,"OWNER ONLY");
        _;
    }

    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _tokenId
    );
    event ContractOwnerChanged(address _newOwner);
    event ValidatorChanged(bytes32 _newValidator);

    uint8[6] referralRate = [0, 0, 1, 3, 5]; // grade 1, 2, 3, 4, 5
    string[] tags = ["L1", "L2", "defi", "nft", "gamefi", "zero knowleade"];
    bool initialized = false;
    uint last_updated_month;

    function init_imp() external{
        require(initialized == false, "INITIATED ALREADY");
        last_updated_month = DateTime.getMonth(block.timestamp);
        initialized = true;
    }

    // 0x731133e9
    function mint(
        address _address
    ) external {
        require(_address != address(0));
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(sbtstruct.makiList[sbtstruct.address2index[_address]] == 0, "Already minted");
        emit Transfer(address(0), _address, uint256(uint160(_address)));
    }

    function burn(address _address) external onlyOwner {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        delete sbtstruct.makiList[sbtstruct.address2index[_address]];
        emit Transfer(_address, address(0), uint256(uint160(_address)));
    }

    function setBaseUri(string memory _newBaseURI) external onlyOwner {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        sbtstruct.baseURI = _newBaseURI;
    }

    function setContractOwner(address _newContactOwner) external onlyOwner {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        sbtstruct.contractOwner = _newContactOwner;
        emit ContractOwnerChanged(_newContactOwner);
    }

    function setValidator(bytes32 _newValidator) external onlyOwner {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        sbtstruct.validator = _newValidator;
        emit ValidatorChanged(_newValidator);
    }

    function getValidator() external view returns (bytes32) {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.validator;
    }

    // chaininsight functions
    function month_init() public {
        require(DateTime.getMonth(block.timestamp) != last_updated_month);
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();

        //TODO: 薪の付与

        //TODO: グレードの更新
        _update_rate(sbtstruct);

        delete sbtstruct.favoList;
        delete sbtstruct.referralList;
    }

    function _update_rate(SbtLib.SbtStruct storage sbtstruct) internal {
        for (uint i=0; i < sbtstruct.rateList.length; i++){
            sbtstruct.rateList[i] = sbtstruct.makiList[i] * 2 + sbtstruct.rateList[i];
        }
    }

    function _update_grade(SbtLib.SbtStruct storage sbtstruct) internal {

        uint16[] memory rateSortedIndex;
        for (uint16 i=0; i < sbtstruct.rateList.length; i++){
            rateSortedIndex[i] = i;
        }

        rateSortedIndex = QuickSort.sort(sbtstruct.rateList, rateSortedIndex);

        for (uint i=0; i < sbtstruct.gradeList.length; i++){
            if (i <= rateSortedIndex[i] / 20){
                //TODO
            }
        }
    }

    function addTag(string memory tag) external onlyOwner{
        tags.push(tag);
    }

    function removeTag(uint tag_id) external onlyOwner{
        delete tags[tag_id];
    }

    function addMaxStar(address user_address, string memory tag, uint8 star) external {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        if (sbtstruct.maxstarMap[user_address][tag] > star){
            sbtstruct.maxstarMap[user_address][tag] = star;
        }
    }

    // functions for frontend
    function addFavos(address user_from, address user_to, uint8 favo) external {
        require(msg.sender == user_from, "USER ONLY");
        require(favo > 0, "INVALID ARGUMENT");

        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        uint8 remainFavos = sbtstruct.favoList[sbtstruct.address2index[user_from]] - favo;
        require(remainFavos >= 0, "INVALID ARGUMENT");
        sbtstruct.favoList[sbtstruct.address2index[user_from]] = remainFavos;
        sbtstruct.receivedFavoList[sbtstruct.address2index[user_to]] += favo;
    }


    function verify(bytes32 _hash, bytes memory _signature)
        public
        view
        returns (bool)
    {
        /** メモ: @shion
         * https://solidity-by-example.org/signature/
         * _hash：keccack(msg, nonce, ...) 署名時に用いるメッセージハッシュ
         * _singnature：{r, s, v} 署名されたメッセージ．r)0-32byte目，s)32-64byte目，v)65byte目
         * ecrecover：メッセージハッシュと署名されたメッセージから公開鍵を復元する関数
         * 最後は solidity example では公開鍵を直接比較して検証しているが，今回はそれにハッシュをかけたものを用いて検証している．
         */
        require(_signature.length == 65, "INVALID");
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        bytes32 _r;
        bytes32 _s;
        uint8 _v;
        assembly {
            _r := mload(add(_signature, 32))
            _s := mload(add(_signature, 64))
            _v := byte(0, mload(add(_signature, 96)))
        }
        return
            keccak256(abi.encodePacked(ecrecover(_hash, _v, _r, _s))) ==
            sbtstruct.validator;
    }
}