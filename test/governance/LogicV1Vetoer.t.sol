pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/governance/ProxyV1.sol";
import "../../src/governance/LogicV1.sol";
import "../../src/governance/ExecutorV1.sol";
// import "../../src/governance/InterfacesV1.sol";
import "../../src/bonfire/BonfireProxy.sol";

contract ChainInsightLogicV1VetoerTest is Test {
    ChainInsightGovernanceProxyV1 internal proxy;
    ChainInsightLogicV1 internal logic;
    ChainInsightExecutorV1 internal executor;
    Bonfire internal bonfire;

    address admin = address(1);
    address logicAdminTmp = address(0);
    address vetoer = address(2);
    uint256 executingGracePeriod = 11520;
    uint256 executingDelay = 11520;
    uint256 votingPeriod = 5760;
    uint256 votingDelay = 1;
    uint8 proposalThreshold = 1;

    function setUp() public {
        logic = new ChainInsightLogicV1();
        executor = new ChainInsightExecutorV1();
        bonfire = new Bonfire();

        vm.prank(admin);
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

        vm.prank(logicAdminTmp);
        logic.initialize(
            address(bonfire),
            vetoer,
            executingGracePeriod,
            executingDelay,
            votingPeriod,
            votingDelay,
            proposalThreshold
        );
    }

    function testSetPendingVetoer() public {
        address pendingVetoer = address(55);

        assertFalse(logic.pendingVetoer() == pendingVetoer);

        vm.prank(vetoer);
        logic._setPendingVetoer(pendingVetoer);

        assertTrue(logic.pendingVetoer() == pendingVetoer);
    }

    function testAcceptVetoer() public {
        address pendingVetoer = address(55);

        assertFalse(logic.vetoer() == pendingVetoer);

        vm.prank(vetoer);
        logic._setPendingVetoer(pendingVetoer);

        vm.prank(pendingVetoer);
        logic._acceptVetoer();

        assertTrue(logic.vetoer() == pendingVetoer);
    }

    function testBurnVetoPower() public {
        assertFalse(logic.vetoer() == address(0));

        // set pending vetoer
        address pendingVetoer = address(55);

        vm.prank(vetoer);
        logic._setPendingVetoer(pendingVetoer);

        assertFalse(logic.pendingVetoer() == address(0));
        // set vetoer and pending vetoer to address 0
        vm.prank(vetoer);
        logic._burnVetoPower();

        assertTrue(logic.vetoer() == address(0));
        assertTrue(logic.pendingVetoer() == address(0));
    }
}
