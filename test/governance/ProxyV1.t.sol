pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/governance/ProxyV1.sol";

contract ChainInsightGovernanceProxyV1Test is Test {
    ChainInsightGovernanceProxyV1 internal proxy;

    address executorContract = address(1);
    address sbtContract = address(2); 
    address admin = address(3);
    address implementation = address(4);
    uint256 executingGracePeriod = 11520;
    uint256 executingDelay = 11520;
    uint256 votingPeriod = 5760;
    uint256 votingDelay = 1;
    uint256 proposalThreshold = 1;

    function setUp() public {
        proxy = new ChainInsightGovernanceProxyV1(
            implementation,
            executorContract,
            sbtContract,
            admin,
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

    function testSetImplementationAndInitialize() public {
        assertEq(proxy.implementation(), implementation);

        address newImplementation = address(44);

        vm.prank(admin);
        proxy.setImplementationAndInitialize(
            newImplementation,
            executorContract,
            sbtContract,
            admin,
            executingGracePeriod,
            executingDelay,
            votingPeriod,
            votingDelay,
            proposalThreshold
        );

        assertEq(proxy.implementation(), newImplementation);
    }

}


