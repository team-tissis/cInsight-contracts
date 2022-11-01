pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/governance/ProxyV1.sol";
import "../../src/governance/LogicV1.sol";

contract ChainInsightGovernanceLogicV1Test is Test {
    ChainInsightGovernanceProxyV1 internal proxy;
    ChainInsightLogicV1 internal logic;

    address implementation = 0x3333333333333333333333333333333333333333;
    address executorContract = 0x4444444444444444444444444444444444444444;
    address admin = 0x1111111111111111111111111111111111111111;
    address vetoer = 0x5555555555555555555555555555555555555555;
    uint256 executingGracePeriod = 11520;
    uint256 executingDelay = 11520;
    uint256 votingPeriod = 5760;
    uint256 votingDelay = 1;
    uint8 proposalThreshold = 1;

    address[] targets = [0x6666666666666666666666666666666666666666];
    uint256[] values = [0];
    string[] signatures = ["func(uint)"];
    bytes[] calldatas = [abi.encodePacked("5")];
    string  description = "Some proposal";
    
    function setUp() public {

        logic = new ChainInsightLogicV1();
        
        // TODO: raise error
        // delegatecall seems to call _setImplementation...
        proxy = new ChainInsightGovernanceProxyV1(
            address(logic),
            executorContract,
            vetoer,
            executingGracePeriod,
            executingDelay,
            votingPeriod,
            votingDelay
        );

        logic.initialize(
            executorContract,
            vetoer,
            executingGracePeriod,
            executingDelay,
            votingPeriod,
            votingDelay,
            proposalThreshold
        );
    }

    function testProposeToExecute() public {
        // set block.number to 0
        vm.roll(0);
        logic.propose(
            targets,
            values,
            signatures,
            calldatas,
            description
        );
        emit log_uint(block.number); // 100

        // voting starts
        vm.roll(votingDelay + 1);
        // TODO: retrieve ownership info of SBT
        // logic.castVote(1, 1);

        // voting ends
        vm.roll(votingDelay + votingPeriod + 1);
    }

    // function testQueue() public {
    //     logic.queue(5);
    // }

}
