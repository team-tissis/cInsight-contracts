pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/governance/ProxyV1.sol";
import "../../src/governance/ExecutorV1.sol";

contract ChainInsightExecutorV1Test is Test {
    ChainInsightExecutorV1 internal executor;

    ChainInsightGovernanceProxyV1 internal proxy;
    ChainInsightGovernanceProxyV1 internal newProxy;

    address deployer = address(1);

    uint256 executingGracePeriod = 11520;
    uint256 executingDelay = 11520;
    uint256 votingPeriod = 5760;
    uint256 votingDelay = 1;
    uint8 proposalThreshold = 1;

    
    function setUp() public {
        proxy = new ChainInsightGovernanceProxyV1(
            address(2),
            address(3),
            address(4),
            address(5),
            executingGracePeriod,
            executingDelay,
            votingPeriod,
            votingDelay,
            proposalThreshold
        );

        vm.prank(deployer);
        executor = new ChainInsightExecutorV1();

        // call must be deployer for the second time
        vm.prank(deployer);
        executor.setProxyAddress(address(proxy));
    }

    function testConstructor() public {
        assertEq(executor.proxyAddress(), address(proxy));
    }

    function testSetLogicAddress() public {
        assertFalse(executor.proxyAddress() == address(newProxy));

        // call must be proxy for the second time
        vm.prank(address(executor));
        executor.setProxyAddress(address(newProxy));

        assertTrue(executor.proxyAddress() == address(newProxy));
    }
}
