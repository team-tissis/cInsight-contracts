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

    address admin = address(1);
    address vetoer = address(2);
    uint256 executingGracePeriod = 11520;
    uint256 executingDelay = 11520;
    uint256 votingPeriod = 5760;
    uint256 votingDelay = 1;
    uint8 proposalThreshold = 1;
    
    function setUp() public {
        logic = new ChainInsightLogicV1();
        executor = new ChainInsightExecutorV1(address(logic));
        sbt = new Sbt();
        
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
    }

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
