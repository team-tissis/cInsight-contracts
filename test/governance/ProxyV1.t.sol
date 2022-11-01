pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/governance/ProxyV1.sol";

contract ChainInsightGovernanceProxyV1Test is Test {
    ChainInsightGovernanceProxyV1 internal proxy;

    address executorContract = 0x4444444444444444444444444444444444444444;
    address admin = 0x1111111111111111111111111111111111111111;
    uint256 executingGracePeriod = 11520;
    uint256 executingDelay = 11520;
    uint256 votingPeriod = 5760;
    uint256 votingDelay = 1;
    uint256 proposalThreshold = 1;

    function setUp() public {
        address implementation = 0x3333333333333333333333333333333333333333;

        proxy = new ChainInsightGovernanceProxyV1(
            implementation,
            executorContract,
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
        address newImplementation = 0xa333333333333333333333333333333333333333;

        vm.prank(admin);

        proxy.setImplementationAndInitialize(
            newImplementation,
            executorContract,
            admin,
            executingGracePeriod,
            executingDelay,
            votingPeriod,
            votingDelay
        );

        assertEq(proxy.implementation(), newImplementation);
    }

}


