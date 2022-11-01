pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/governance/ProxyV1.sol";
import "../../src/governance/LogicV1.sol";
import "../../src/governance/ExecutorV1.sol";
// import "../../src/governance/InterfacesV1.sol";
import "../../src/sbt/Sbt.sol";

contract ChainInsightGovernanceLogicV1Test is Test {
    ChainInsightGovernanceProxyV1 internal proxy;
    ChainInsightLogicV1 internal logic;
    ChainInsightExecutorV1 internal executor;
    Sbt internal sbt;

    struct Proposal {
        /// @notice Unique id for looking up a proposal
        uint256 id;
        /// @notice Creator of the proposal
        address proposer;

        /// @notice The timestamp that the proposal will be available for execution, set once the vote succeeds
        uint256 eta;

        /// @notice the ordered list of target addresses for calls to be made
        address[] targets;
        /// @notice The ordered list of values (i.e. msg.value) to be passed to the calls to be made
        uint256[] values;
        /// @notice The ordered list of function signatures to be called
        string[] signatures;
        /// @notice The ordered list of calldata to be passed to each call
        bytes[] calldatas;


        /// @notice The block at which voting begins: holders must delegate their votes prior to this block
        uint256 startBlock;
        /// @notice The block at which voting ends: votes must be cast prior to this block
        uint256 endBlock;

        /// @notice Current number of votes in favor of this proposal
        uint256 forVotes;

        /// @notice Current number of votes in opposition to this proposal
        uint256 againstVotes;

        /// @notice Current number of votes for abstaining for this proposal
        uint256 abstainVotes;

        /// @notice Flag marking whether the proposal has been canceled
        bool canceled;
        /// @notice Flag marking whether the proposal has been vetoed
        bool vetoed;
        /// @notice Flag marking whether the proposal has been executed
        bool executed;

        /// @notice Receipts of ballots for the entire set of voters
        mapping(address => Receipt) receipts;
    }

    address admin = address(1);
    address vetoer = address(5);
    uint256 executingGracePeriod = 11520;
    uint256 executingDelay = 11520;
    uint256 votingPeriod = 5760;
    uint256 votingDelay = 1;
    uint8 proposalThreshold = 1;

    address[] targets = [address(6)];
    uint256[] values = [0];
    string[] signatures = ["func(uint)"];
    bytes[] calldatas = [abi.encodePacked("5")];
    string  description = "Some proposal";
    
    function setUp() public {
        logic = new ChainInsightLogicV1();
        executor = new ChainInsightExecutorV1(address(logic));
        sbt = new Sbt();
        
        // vm.prank(admin);
        proxy = new ChainInsightGovernanceProxyV1(
            address(logic),
            address(executor),
            address(sbt),
            admin,
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
    }

    function testPropose() public {
        // set block.number to 0
        vm.roll(0);
        vm.prank(address(99));
        uint256 proposalId = logic.propose(
                                targets,
                                values,
                                signatures,
                                calldatas,
                                description
                             );

        assertEq(proposalId, 1);
        assertEq(logic.latestProposalIds(address(99)), 1);

        // // voting starts
        // vm.roll(votingDelay + 1);
        // logic.castVote(1, 1);

        // // voting ends
        // vm.roll(votingDelay + votingPeriod + 1);
    }

    // function testSetExecutingGracePeriod() public {
    //     uint256 newExecutingGracePeriod = executingGracePeriod + 100;

    //     vm.prank(admin);
    //     logic._setExecutingGracePeriod(newExecutingGracePeriod);

    //     assertEq(logic.executingGracePeriod(), newExecutingGracePeriod);
    // }

    function TestSetPendingVetoer() public {
        assertEq(logic.pendingVetoer(), address(0));

        address pendingVetoer = address(55);

        vm.prank(vetoer);
        logic._setPendingVetoer(pendingVetoer);

        assertEq(logic.pendingVetoer(), pendingVetoer);
    }

    function TestAcceptVetoer() public {
        assertEq(logic.vetoer(), address(0));

        address pendingVetoer = address(55);

        vm.prank(vetoer);
        logic._setPendingVetoer(pendingVetoer);

        vm.prank(pendingVetoer);
        logic._acceptVetoer();

        assertEq(logic.vetoer(), pendingVetoer);
    }

    function TestBurnVetoPower() public {
        assertEq(logic.vetoer(), vetoer);
        assertEq(logic.pendingVetoer(), address(0));

        // set pending vetoer
        address pendingVetoer = address(55);

        vm.prank(vetoer);
        logic._setPendingVetoer(pendingVetoer);

        // set vetoer and pending vetoer to address 0
        vm.prank(vetoer);
        logic._burnVetoPower();

        assertEq(logic.vetoer(), address(0));
        assertEq(logic.pendingVetoer(), address(0));
    }
}
