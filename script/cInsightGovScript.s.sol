// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Script.sol";
import {ChainInsightLogicV1} from "src/governance/LogicV1.sol";
import {ChainInsightExecutorV1} from "src/governance/ExecutorV1.sol";
import {ChainInsightGovernanceProxyV1} from "src/governance/ProxyV1.sol";
import {Bonfire} from "src/bonfire/Bonfire.sol";
import {BonfireImp} from "src/bonfire/BonfireImp.sol";
import {SkinNft} from "src/skinnft/SkinNft.sol";
import {ISkinNft} from "src/skinnft/ISkinNft.sol";

contract cInsightGovScript is Script {
    ChainInsightLogicV1 logic;
    ChainInsightExecutorV1 executor;
    ChainInsightGovernanceProxyV1 proxy;
    Bonfire bonfire;
    BonfireImp bonfireImp;
    SkinNft skinNft;

    address admin = address(1);
    address vetoer = address(2);

    uint256 executingGracePeriod = 11520;
    uint256 executingDelay = 11520;
    uint256 votingPeriod = 5760;
    uint256 votingDelay = 1;
    uint8 proposalThreshold = 1;

    string baseURL = "https://thechaininsight.github.io/";

    // --- newly added ---
    ChainInsightLogicV1 newLogic;

    address proposer = address(3);
    address voter = address(4);

    address targets; // will be set later
    uint256 values = 0;
    bytes calldatas; // will be set later
    string signatures = "setLogicAddress(address)";
    string description =
        "ChainInsightExecutorV1: Change address of logic contract";
    uint256[] proposalIds = new uint256[](2);
    uint256[] etas = new uint256[](2);
    bytes32[] txHashs = new bytes32[](2);

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPROYER_KEY");
        address deployerAddress = vm.envAddress("CONTRACT_ADDRESS");

        // excute operations as a deployer account until stop broadcast
        vm.startBroadcast(deployerPrivateKey);

        logic = new ChainInsightLogicV1();
        executor = new ChainInsightExecutorV1();
        bonfire = new Bonfire();
        bonfireImp = new BonfireImp();
        skinNft = new SkinNft(string.concat(baseURL, "skinnft/"));

        proxy = new ChainInsightGovernanceProxyV1(
            address(logic),
            address(executor),
            address(sbt),
            address(bonfire),
            vetoer,
            executingGracePeriod,
            executingDelay,
            votingPeriod,
            votingDelay,
            proposalThreshold
        );

        executor.setProxyAddress(address(proxy));

        console.log(
            "address(proxy), address(logic), address(executor), address(bonfire), address(bonfireImp), address(skinNft)"
        );
        console.log(address(proxy));
        console.log(address(logic));
        console.log(address(executor));
        console.log(address(bonfire));
        console.log(address(bonfireImp));
        console.log(address(skinNft));
        bonfire.init(
            address(executor),
            "ChainInsight",
            "SBT",
            string.concat(baseURL, "bonfire/"),
            20 ether,
            address(skinNft),
            address(bonfireImp)
        );
        skinNft.init(address(bonfire));

        // --- newly added ---
        newLogic = new ChainInsightLogicV1();
        targets = address(executor);
        calldatas = abi.encode(address(newLogic));

        // vm.stopBroadcast();

        // // mint SBT to obtain voting right
        // vm.startBroadcast(address(proposer));
        // vm.deal(proposer, 10000 ether);
        // // address(bonfire).call{value: 26 ether}(abi.encodeWithSignature("mint()"));
        // vm.stopBroadcast();

        // vm.startBroadcast(address(voter));
        // vm.deal(voter, 10000 ether);
        // address(bonfire).call{value: 26 ether}(abi.encodeWithSignature("mint()"));
        // vm.stopBroadcast();

        // vm.startBroadcast(address(voter));

        address(bonfire).call{value: 26 ether}(
            abi.encodeWithSignature("mint()")
        );

        // // set block.number to 0
        // vm.roll(0);
        // // propose
        // (bool success, bytes memory returnData) = address(proxy).call(
        //     abi.encodeWithSignature(
        //         'propose(address[],uint256[],string[],bytes[],string)',
        //         targets,
        //         values,
        //         signatures,
        //         calldatas,
        //         description
        //     )
        // );

        vm.stopBroadcast();
    }
}
