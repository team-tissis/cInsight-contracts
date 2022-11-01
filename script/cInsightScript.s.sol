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

    address admin = address(9);
    string baseURL = "https://thechaininsight.github.io/";

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPROYER_KEY");

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
            address(skinNft),
            address(sbtImp)
        );
        skinNft.init(address(sbt));

        vm.stopBroadcast();
    }
}
