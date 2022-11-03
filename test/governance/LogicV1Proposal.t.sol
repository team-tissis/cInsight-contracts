pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/governance/ProxyV1.sol";
import "../../src/governance/LogicV1.sol";
import "../../src/governance/ExecutorV1.sol";
import "../../src/sbt/Sbt.sol";
import "../../src/sbt/SbtImp.sol";

contract ChainInsightLogicV1PropososalTest is Test {
    ChainInsightGovernanceProxyV1 internal proxy;
    ChainInsightLogicV1 internal logic;
    ChainInsightLogicV1 internal newLogic;
    ChainInsightExecutorV1 internal executor;
    Sbt internal sbt;
    SbtImp internal imp;

    address admin = address(1);
    address logicAdminTmp = address(0);
    address vetoer = address(2);
    address proposer = address(3);
    address voter = address(4);
    address nftAddress = address(5);

    uint256 executingGracePeriod = 11520;
    uint256 executingDelay = 11520;
    uint256 votingPeriod = 5760;
    uint256 votingDelay = 1;
    uint8 proposalThreshold = 1;

    // propose info
    address[] targets; // will be set later
    uint256[] values = [0];
    bytes[] calldatas; // will be set later
    string[] signatures = ["setLogicAddress(address)"];
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

        targets = [address(executor)];
        calldatas = [abi.encode(address(newLogic))];

        vm.prank(admin);
        proxy = new ChainInsightGovernanceProxyV1(
            address(logic),
            address(executor),
            address(sbt),
            admin,
            vetoer,
            executingGracePeriod,
            executingDelay,
            votingPeriod,
            votingDelay,
            proposalThreshold
        );

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
            nftAddress,
            address(imp)
        );

        // mint SBT to obtain voting right
        vm.deal(proposer, 10000 ether);
        vm.prank(proposer);
        address(sbt).call{value: 26 ether}(abi.encodeWithSignature("mint()"));

        vm.deal(voter, 10000 ether);
        vm.prank(voter);
        address(sbt).call{value: 26 ether}(abi.encodeWithSignature("mint()"));

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

    function testPropose() public {
        assertEq(proposalIds[0], 1);
        assertEq(logic.latestProposalIds(proposer), 1);
    }

    function testQueue() public {
        assertTrue(executor.queuedTransactions(txHashs[0]));
    }

    function testExecute() public {
        assertTrue(executor.queuedTransactions(txHashs[0]));
        assertFalse(executor.logicAddress() == address(newLogic));
        (, , , , , , , , , , bool oldExecuted) = logic.proposals(proposalIds[0]);
        assertFalse(oldExecuted);

        vm.roll(votingDelay + votingPeriod + executingDelay + 1);
        logic.execute(proposalIds[0]);

        assertFalse(executor.queuedTransactions(txHashs[0]));
        assertTrue(executor.logicAddress() == address(newLogic));
        (, , , , , , , , , , bool newExecuted) = logic.proposals(proposalIds[0]);
        assertTrue(newExecuted);
    }

    function testCancel() public {
        assertTrue(executor.queuedTransactions(txHashs[0]));
        (, , , , , , , , bool oldCanceled, ,) = logic.proposals(proposalIds[0]);
        assertFalse(oldCanceled);

        vm.prank(proposer);
        logic.cancel(proposalIds[0]);

        assertFalse(executor.queuedTransactions(txHashs[0]));
        (, , , , , , , , bool newCanceled, ,) = logic.proposals(proposalIds[0]);
        assertTrue(newCanceled);
    }

    function testVeto() public {
        (, , , , , , , , , bool oldVetoed,) = logic.proposals(proposalIds[0]);
        assertFalse(oldVetoed);
        assertTrue(executor.queuedTransactions(txHashs[0]));

        vm.prank(vetoer);
        logic.veto(proposalIds[0]);

        (, , , , , , , , , bool newVetoed,) = logic.proposals(proposalIds[0]);
        assertTrue(newVetoed);
        assertFalse(executor.queuedTransactions(txHashs[0]));
    }

    receive() external payable {}
}
