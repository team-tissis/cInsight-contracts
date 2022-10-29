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


    // 0x731133e9
    function mint(
        address minter 
    ) external {
        require(minter != address(0));
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(sbtstruct.grades[minter] == 0, "Already minted");
        _mint(sbtstruct, minter);
        emit Transfer(address(0), minter, sbtstruct.mintIndex);
    }

    function _mint(SbtLib.SbtStruct storage sbtstruct, address minter) internal {
        sbtstruct.mintIndex += 1;
        sbtstruct.owners[sbtstruct.mintIndex] = minter;
        sbtstruct.grades[minter] = 1;
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

    function setBaseUri(string memory _newBaseURI) external onlyOwner {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        sbtstruct.baseURI = _newBaseURI;
    }

    function setContractOwner(address _newContactOwner) external onlyOwner {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        sbtstruct.contractOwner = _newContactOwner;
        emit ContractOwnerChanged(_newContactOwner);
    }

    function getValidator() external view returns (bytes32) {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.validator;
    }
    
    function setValidator(bytes32 _newValidator) external onlyOwner {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        sbtstruct.validator = _newValidator;
        emit ValidatorChanged(_newValidator);
    }

    function getFavo(address _address) external view returns (uint){
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.favos[_address];
    }

    function getMaki(address _address) external view returns (uint){
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.makis[_address];
    }

    function getGrade(address _address) external view returns (uint){
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.grades[_address];
    }

    function getRate(address _address) external view returns (uint){
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.rates[_address];
    }

    function getReferral(address _address) external view returns (uint){
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.referrals[_address];
    }

    function getNftPoint(address _address) external view returns (uint){
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.nftPoints[_address];
    }
    
    function getFavoNum() external view returns (uint){
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.favoNum;
    }

    function setFavoNum(uint8 _favoNum) external onlyOwner{
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        sbtstruct.favoNum = _favoNum;
    }

    function getReferralRate() external view returns (uint8[] memory){
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.referralRate;
    }

    function setReferralRate(uint8[] memory _referralRate) external onlyOwner {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();

        // TODO: referralRateのサイズを大きくしたときの挙動
        for (uint i = 0; i < _referralRate.length; i++){
                sbtstruct.referralRate[i] = _referralRate[i];
        }
    }

    function getLastUpdatedMonth() external view returns (uint){
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        return sbtstruct.lastUpdatedMonth;
    }

    // chaininsight functions
    function imp_init() external onlyOwner{
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        sbtstruct.favoNum = 20;
        sbtstruct.lastUpdatedMonth = uint8(DateTime.getMonth(block.timestamp));

        uint8[5] memory _referralRate = [0, 0, 1, 3, 5]; // grade 1,2,3,4,5
        for (uint i = 0; i < 5; i++){
            sbtstruct.referralRate.push(_referralRate[i]);
        }
    }

    function month_init() public {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        require(DateTime.getMonth(block.timestamp) != sbtstruct.lastUpdatedMonth);

        _addMakiForDoneFavo(sbtstruct);
        
        _updateRate(sbtstruct);
        _updateGrade(sbtstruct);

        // burn されたアカウントも代入計算を行なっている．
        // TODO: sstore 0->0 はガス代がかなり安いらしいが，より良い実装はありうる．
        for (uint i = 1; i <= sbtstruct.mintIndex; i++){
            address _address = sbtstruct.owners[i]; //TODO: このようにmemoryに一時保存すると安い？
            sbtstruct.favos[_address] = 0;
            sbtstruct.referrals[_address] = 0;
        }
    }

    function _addMakiForDoneFavo(SbtLib.SbtStruct storage sbtstruct) internal {
        for (uint i = 1; i <= sbtstruct.mintIndex; i++){
            address _address = sbtstruct.owners[i]; //TODO: このようにmemoryに一時保存すると安い？

            if (sbtstruct.favos[_address] == sbtstruct.favoNum){
                sbtstruct.makis[_address] += 5;
            }
        }
    }

    function _updateRate(SbtLib.SbtStruct storage sbtstruct) internal {
        for (uint i = 1; i <= sbtstruct.mintIndex; i++){
            address _address = sbtstruct.owners[i];

            sbtstruct.rates[_address] = sbtstruct.makis[_address] + sbtstruct.rates[_address] / 4;
        }
    }

    function _updateGrade(SbtLib.SbtStruct storage sbtstruct) internal {

        uint accountNum = sbtstruct.mintIndex - sbtstruct.burnNum;
        uint16[] memory rateSortedIndex = new uint16[](accountNum);
        uint32[] memory rateArray = new uint32[](accountNum);

        uint count;
        for (uint i = 1; i <= sbtstruct.mintIndex; i++){
            address _address = sbtstruct.owners[i];
            if (_address != address(0)){
                count += 1;
                rateSortedIndex[count] = uint16(i);
                rateArray[count] = uint32(sbtstruct.rates[_address]);
            }
        }
        rateSortedIndex = QuickSort.sort(rateArray, rateSortedIndex);

        // burnされていない account 中の上位 x %を計算.
        for (uint i=0; i < accountNum; i++){
            if (i <= accountNum / 20){ // 上位 5%
                sbtstruct.grades[sbtstruct.owners[rateSortedIndex[i]]] = 5;
            } else if (i <= accountNum / 5){ // 上位 20%
                sbtstruct.grades[sbtstruct.owners[rateSortedIndex[i]]] = 4;
            } else if (i <= accountNum / 5 * 2){ // 上位 40%
                sbtstruct.grades[sbtstruct.owners[rateSortedIndex[i]]] = 3;
            } else if (i <= accountNum / 5 * 4){ // 上位 80%
                sbtstruct.grades[sbtstruct.owners[rateSortedIndex[i]]] = 2;
            } else{
                sbtstruct.grades[sbtstruct.owners[rateSortedIndex[i]]] = 1;
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
        if (remainFavo <= favo){
            addFavoNum = remainFavo;
        } else{
            addFavoNum = favo;
        }

        sbtstruct.favos[msg.sender] = addFavoNum;
        sbtstruct.makis[userTo] += favo; // makiの計算
    }

    function reffer(address userTo) external {

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