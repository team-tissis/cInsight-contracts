pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/governance/ProxyV1.sol";
import "../../src/governance/LogicV1.sol";

contract ChainInsightGovernanceProxyV1Test is Test {
    ChainInsightGovernanceProxyV1 internal proxy;
    ChainInsightLogicV1 internal logic;
    ChainInsightLogicV1 internal newLogic;


    address executorContract = address(1);
    address sbtContract = address(2); 
    address admin = address(3);
    address vetoer = address(4);
    address implementation = address(5);
    uint256 executingGracePeriod = 11520;
    uint256 executingDelay = 11520;
    uint256 votingPeriod = 5760;
    uint256 votingDelay = 1;
    uint256 proposalThreshold = 1;

    function setUp() public {
        logic = new ChainInsightLogicV1();
        vm.prank(admin);
        proxy = new ChainInsightGovernanceProxyV1(
            // implementation,
            address(logic),
            executorContract,
            sbtContract,
            admin,
            vetoer,
            executingGracePeriod,
            executingDelay,
            votingPeriod,
            votingDelay,
            proposalThreshold
        );
    }

    function testConstructor() public {
        assertEq(proxy.admin(), admin);
    }

    function testSetImplementation() public {
        assertEq(proxy.implementation(), address(logic));

        newLogic = new ChainInsightLogicV1();

        assertFalse(address(logic) == address(newLogic));

        vm.prank(admin);
        proxy._setImplementation(address(newLogic));

        // check that proxy implementation is setted
        assertEq(proxy.implementation(), address(newLogic));
    }
}


