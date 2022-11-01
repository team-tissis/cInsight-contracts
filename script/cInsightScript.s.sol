// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

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

        bytes4[] memory sigs = new bytes4[](4);
        address[] memory impAddress = new address[](4);
        sigs[0] = bytes4(keccak256("mint()"));
        sigs[1] = bytes4(keccak256("mintWithReferral(address)"));
        sigs[2] = bytes4(keccak256("refer(address)"));
        sigs[3] = bytes4(keccak256("impInit()"));
        impAddress[0] = address(imp);
        impAddress[1] = address(imp);
        impAddress[2] = address(imp);
        impAddress[3] = address(imp);

        vm.prank(admin);
        sbt.setImplementation(sigs, impAddress);

        vm.stopBroadcast();
    }
}