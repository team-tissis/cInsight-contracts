pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/governance/ProxyV1.sol";
import "../../src/governance/LogicV1.sol";
import "../../src/governance/ExecutorV1.sol";
import "../../src/sbt/Sbt.sol";
import "../../src/sbt/SbtImp.sol";
import "../../src/skinnft/SkinNft.sol";

// test skinnft setfreemintquantity can call via govenance logic
contract ChainInsightLogicV1PropososalTest is Test {
    ChainInsightGovernanceProxyV1 internal proxy;
    ChainInsightLogicV1 internal logic;
    ChainInsightLogicV1 internal newLogic;
    ChainInsightExecutorV1 internal executor;
    Sbt internal sbt;
    SbtImp internal imp;
    SkinNft internal skinNft;

    address admin = address(1);
    address logicAdminTmp = address(0);
    address vetoer = address(2);
    address proposer = address(3);
    address voter = address(4);
    address nftAddress = address(5);
    address beef = address(0xBEEF);

    uint256 executingGracePeriod = 11520;
    uint256 executingDelay = 11520;
    uint256 votingPeriod = 5760;
    uint256 votingDelay = 1;
    uint8 proposalThreshold = 1;

    // propose info
    address[] targets; // will be set later
    uint256[] values = [0];
    bytes[] calldatas; // will be set later
    string[] signatures = ["setFreemintQuantity(address,uint256)"];
    string description =
        "ChainInsightExecutorV1: Change address of logic contract";
    uint256[] proposalIds = new uint256[](2);
    uint256[] etas = new uint256[](2);
    bytes32[] txHashs = new bytes32[](2);

    function setUp() public {
        // create and initialize contracts
        logic = new ChainInsightLogicV1();
        newLogic = new ChainInsightLogicV1();
        executor = new ChainInsightExecutorV1(address(logic));
        sbt = new Sbt();
        imp = new SbtImp();
        skinNft = new SkinNft("");
        skinNft.init(address(sbt));

        targets = [address(sbt)];
        calldatas = [abi.encode(beef, 100)];

        vm.prank(logicAdminTmp);
        logic.initialize(
            address(executor),
            address(sbt),
            vetoer,
            executingGracePeriod,
            executingDelay,
            votingPeriod,
            votingDelay,
            proposalThreshold
        );

        sbt.init(
            address(executor),
            "ChainInsight",
            "SBT",
            "https://thechaininsight.github.io/sbt/",
            address(skinNft),
            address(imp)
        );

        // mint SBT to obtain voting right
        vm.deal(proposer, 10000 ether);
        vm.prank(proposer);
        address(sbt).call{value: 20 ether}(abi.encodeWithSignature("mint()"));

        vm.deal(voter, 10000 ether);
        vm.prank(voter);
        address(sbt).call{value: 20 ether}(abi.encodeWithSignature("mint()"));

        vm.deal(beef, 10000 ether);
        vm.prank(beef);
        address(sbt).call{value: 20 ether}(abi.encodeWithSignature("mint()"));

        // set block.number to 0

        vm.roll(0);

        // propose
        vm.prank(proposer);
        proposalIds[0] = logic.propose(
            targets,
            values,
            signatures,
            calldatas,
            description
        );

        // voting starts
        vm.roll(votingDelay + 1);
        vm.prank(voter);
        logic.castVote(proposalIds[0], 1);

        // voting ends
        vm.roll(votingDelay + votingPeriod + 1);

        // queue proposal
        logic.queue(proposalIds[0]);
        etas[0] = block.number + executingDelay;
        txHashs[0] = keccak256(
            abi.encode(
                targets[0],
                values[0],
                signatures[0],
                calldatas[0],
                etas[0]
            )
        );
    }

    function testExecute() public {
        assertTrue(executor.queuedTransactions(txHashs[0]));
        vm.roll(votingDelay + votingPeriod + executingDelay + 1);
        logic.execute(proposalIds[0]);
        assertEq(skinNft.getFreemintQuantity(beef), 100);
    }

    receive() external payable {}
}
