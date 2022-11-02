pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/governance/ProxyV1.sol";
import "../../src/governance/LogicV1.sol";
import "../../src/governance/ExecutorV1.sol";
// import "../../src/governance/InterfacesV1.sol";
import "../../src/sbt/Sbt.sol";
import "../../src/sbt/SbtImp.sol";

contract ChainInsightGovernanceLogicV1Test is Test {
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
    string[] signatures = ["gradeOf(address)"];
    bytes[] calldatas = [abi.encode(voter)];
    string description = "Check grade of voter";
    
    function setUp() public {
        logic = new ChainInsightLogicV1();
        executor = new ChainInsightExecutorV1(address(logic));
        sbt = new Sbt();
        targets = [address(sbt)];

        imp = new SbtImp();
        
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

        // sbt initialization
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
    }

    function testProposeToExecute() public {
        sbt.favoOf(voter);
        // mint SBT to obtain voting right
        vm.deal(voter, 10000 ether);
        vm.prank(voter);
        address(sbt).call{value: 26 ether}(abi.encodeWithSignature("mint()"));

        // set block.number to 0
        vm.roll(0);

        vm.prank(proposer);
        uint256 proposalId = logic.propose(
                                targets,
                                values,
                                signatures,
                                calldatas,
                                description
                             );

        assertEq(proposalId, 1);
        assertEq(logic.latestProposalIds(proposer), 1);

        // voting starts
        vm.roll(votingDelay + 1);
        vm.prank(voter);
        logic.castVote(proposalId, 1);

        // voting ends
        vm.roll(votingDelay + votingPeriod + 1);

        logic.queue(proposalId);

        vm.roll(votingDelay + votingPeriod + executingDelay + 1);
        logic.execute(proposalId);
    }

    receive() external payable {}
}
