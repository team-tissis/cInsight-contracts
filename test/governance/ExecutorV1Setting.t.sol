pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/governance/LogicV1.sol";
import "../../src/governance/ExecutorV1.sol";

contract ChainInsightExecutorV1Test is Test {
    ChainInsightExecutorV1 internal executor;
    ChainInsightLogicV1 internal logic;
    ChainInsightLogicV1 internal newLogic;
    
    function setUp() public {
        logic = new ChainInsightLogicV1();
        executor = new ChainInsightExecutorV1(address(logic));
    }

    function testConstructor() public {
        assertEq(executor.logicAddress(), address(logic));
    }

    function testSetLogicAddress() public {
        assertFalse(executor.logicAddress() == address(newLogic));

        vm.prank(address(executor));
        executor.setLogicAddress(address(newLogic));

        assertTrue(executor.logicAddress() == address(newLogic));
    }
}
