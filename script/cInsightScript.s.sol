// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import {Sbt} from "src/sbt/Sbt.sol";
import {SbtImp} from "src/sbt/SbtImp.sol";
import {SkinNft} from "src/skinnft/SkinNft.sol";
import {ISkinNft} from "src/skinnft/ISkinNft.sol";

contract cInsightScript is Script {
    Sbt sbt;
    SbtImp sbtImp;
    SkinNft skinNft;

    address admin = address(0xad000); //TODO: executor に変更
    string baseURL = "https://thechaininsight.github.io/";

    uint256 constant functionNum = 7;
    string[functionNum] constant functionArray = [
        "mint()",
        "mintWithReferral(address)",
        "burn(uint)",
        "setFreemintQuantity(address, uint)",
        "monthInit()",
        "addFavos(address, uint8)",
        "refer(address)"
    ];

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // excute operations as a deployer account until stop broadcast
        vm.startBroadcast(deployerPrivateKey);

        sbt = new Sbt();
        sbtImp = new SbtImp();
        skinNft = new SkinNft(string.concat(baseURL, "skinnft/"));

        sbt.init(
            admin,
            "ChainInsight",
            "SBT",
            string.concat(baseURL, "sbt/"),
            address(skinNft)
        );
        skinNft.init(address(sbt));

        bytes4[] memory sigs = new bytes4[](functionNum);
        address[] memory impAddress = new address[](functionNum);

        for (uint256 i = 0; i < functionNum; i++) {
            sigs[i] = bytes4(keccak256(functionArray[i]));
            impAddress[i] = address(setImp);
        }

        vm.prank(admin);
        sbt.setImplementation(sigs, impAddress);

        vm.stopBroadcast();
    }
}
