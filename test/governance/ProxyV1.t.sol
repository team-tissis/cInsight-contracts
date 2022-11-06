pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/governance/ProxyV1.sol";
import "../../src/governance/LogicV1.sol";

contract ChainInsightGovernanceProxyV1Test is Test {
    ChainInsightGovernanceProxyV1 internal proxy;
    ChainInsightLogicV1 internal logic;
    ChainInsightLogicV1 internal newLogic;

    address executor = address(1);
    address bonfireContract = address(2);
    address deployer = address(3);
    address vetoer = address(4);
    address implementation = address(5);
    uint256 executingGracePeriod = 11520;
    uint256 executingDelay = 11520;
    uint256 votingPeriod = 5760;
    uint256 votingDelay = 1;
    uint256 proposalThreshold = 1;

    function setUp() public {
        logic = new ChainInsightLogicV1();
        vm.prank(deployer);
        proxy = new ChainInsightGovernanceProxyV1(
            address(logic),
            executor,
            bonfireContract,
            vetoer,
            executingGracePeriod,
            executingDelay,
            votingPeriod,
            votingDelay,
            proposalThreshold
        );
    }

    function testConstructor() public {
        assertEq(proxy.deployer(), address(0));
    }

    function testSetImplementation() public {
        assertEq(proxy.implementation(), address(logic));

        newLogic = new ChainInsightLogicV1();

        assertFalse(address(logic) == address(newLogic));

        vm.prank(executor);
        proxy._setImplementation(address(newLogic));

        // check that proxy implementation is setted
        assertEq(proxy.implementation(), address(newLogic));
    }
}
