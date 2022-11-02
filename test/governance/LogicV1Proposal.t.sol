pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/governance/ProxyV1.sol";
import "../../src/governance/LogicV1.sol";
import "../../src/governance/ExecutorV1.sol";
// import "../../src/governance/InterfacesV1.sol";
import "../../src/sbt/Sbt.sol";
import "../../src/sbt/SbtImp.sol";

contract ChainInsightLogicV1PropososalTest is Test {
    ChainInsightGovernanceProxyV1 internal proxy;
    ChainInsightLogicV1 internal logic;
    ChainInsightExecutorV1 internal executor;
    Sbt internal sbt;
    SbtImp internal imp;

    address admin = address(1);
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
    address[] targets; // set later
    uint256[] values = [0];
    // string[] signatures = ["setMonthlyDistributedFavoNum(uint16)"];
    // bytes[] calldatas = [abi.encode(99)];
    string[] signatures = ["gradeOf(address)"];
    bytes[] calldatas = [abi.encode(address(voter))];
    string description = "Check grade of voter";

    uint256[] proposalIds = new uint256[](2);
    uint256[] etas = new uint256[](2);
    bytes32[] txHashs = new bytes32[](2);
    
    function setUp() public {
        // create and initialize contracts
        logic = new ChainInsightLogicV1();
        executor = new ChainInsightExecutorV1(address(logic));
        sbt = new Sbt();
        imp = new SbtImp();

        targets = [address(sbt)];
        
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

        // initialize sbt
        // TODO: admin -> executor
        sbt.init(
            admin,
            "ChainInsight",
            "SBT",
            "https://thechaininsight.github.io/sbt/",
            nftAddress
        );
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

        logic.queue(proposalIds[0]);
        etas[0] = block.number + executingDelay;
        txHashs[0] = keccak256(abi.encode(targets[0], values[0], signatures[0], calldatas[0], etas[0]));
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

        vm.roll(votingDelay + votingPeriod + executingDelay + 1);

        logic.execute(proposalIds[0]);

        assertFalse(executor.queuedTransactions(txHashs[0]));
    }

    function testCancel() public {
        assertTrue(executor.queuedTransactions(txHashs[0]));

        vm.prank(proposer);
        logic.cancel(proposalIds[0]);

        assertFalse(executor.queuedTransactions(txHashs[0]));
    }

    function testVeto() public {
        assertTrue(executor.queuedTransactions(txHashs[0]));

        vm.prank(vetoer);
        logic.veto(proposalIds[0]);

        // TODO: why compile error?
        // assertTrue(logic.proposals(proposalIds[0]).vetoed);
        assertFalse(executor.queuedTransactions(txHashs[0]));
    }

    receive() external payable {}
}
