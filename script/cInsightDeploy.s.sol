// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import {ChainInsightLogicV1} from "src/governance/LogicV1.sol";
import {ChainInsightExecutorV1} from "src/governance/ExecutorV1.sol";
import {ChainInsightGovernanceProxyV1} from "src/governance/ProxyV1.sol";
import {Bonfire} from "src/bonfire/BonfireProxy.sol";
import {BonfireLogic} from "src/bonfire/BonfireLogic.sol";
import {SkinNft} from "src/skinnft/SkinNft.sol";
import {ISkinNft} from "src/skinnft/ISkinNft.sol";

contract cInsightScript is Script {
    ChainInsightLogicV1 logic;
    ChainInsightExecutorV1 executor;
    ChainInsightGovernanceProxyV1 proxy;
    Bonfire bonfire;
    BonfireLogic bonfireLogic;
    SkinNft skinNft;
    uint256 executingGracePeriod = 300;
    uint256 executingDelay = 150;
    uint256 votingPeriod = 150;
    uint256 votingDelay = 1;
    uint8 proposalThreshold = 1;
    string baseURL = "https://team-tissis.github.io/cInsightAsset/";

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // excute operations as a deployer account until stop broadcast
        vm.startBroadcast(deployerPrivateKey);

        logic = new ChainInsightLogicV1();
        executor = new ChainInsightExecutorV1();
        bonfire = new Bonfire();
        bonfireLogic = new BonfireLogic();
        skinNft = new SkinNft(string.concat(baseURL, "skinnft/"));
        address admin = tx.origin;
        address vetoer = address(0);

        proxy = new ChainInsightGovernanceProxyV1(
            address(logic),
            address(executor),
            address(bonfire),
            vetoer,
            executingGracePeriod,
            executingDelay,
            votingPeriod,
            votingDelay,
            proposalThreshold
        );

        executor.setProxyAddress(address(proxy));

        bonfire.init(
            address(executor),
            "Bonfire",
            "SBT",
            string.concat(baseURL, "sbt/metadata/"),
            0.1 ether,
            address(skinNft),
            address(bonfireLogic)
        );
        skinNft.init(address(bonfire));

        vm.stopBroadcast();
    }
}
