pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "../../src/governance/ProxyV1.sol";
import "../../src/governance/LogicV1.sol";
import "../../src/governance/ExecutorV1.sol";
import "../../src/bonfire/BonfireProxy.sol";
import "../../src/bonfire/BonfireLogic.sol";
import "../../src/skinnft/SkinNft.sol";
import "../../src/libs/BonfireLib.sol";

// test skinnft setfreemintquantity can call via govenance logic
contract ChainInsightLogicV1PropososalTest is Test {
    ChainInsightGovernanceProxyV1 internal proxy;
    ChainInsightLogicV1 internal logic;
    ChainInsightLogicV1 internal newLogic;
    ChainInsightExecutorV1 internal executor;
    Bonfire internal bonfire;
    BonfireLogic internal imp;
    SkinNft internal skinNft;

    address admin = address(1);
    address logicAdminTmp = address(0);
    address vetoer = address(2);
    address proposer = address(3);
    address voter = address(4);
    address nftAddress = address(5);
    address beef = address(0xBEEF);
    address deployer = address(6);

    uint256 executingGracePeriod = 11520;
    uint256 executingDelay = 11520;
    uint256 votingPeriod = 5760;
    uint256 votingDelay = 1;
    uint8 proposalThreshold = 1;

    // propose info
    address [] targets; // will be set later
    uint256 [] values = [0, 0];
    bytes [] calldatas; // will be set later
    string [] signatures = ["setFreemintQuantity(address,uint256)", "setMonthlyDistributedFavoNum(uint16)"];
    string description =
        "ChainInsightExecutorV1: Change address of logic contract";
    uint256[] etas = new uint256[](2);
    bytes32[] txHashs = new bytes32[](2);

    function setUp() public {
        // create and initialize contracts
        logic = new ChainInsightLogicV1();
        newLogic = new ChainInsightLogicV1();
        vm.prank(deployer);
        executor = new ChainInsightExecutorV1();
        bonfire = new Bonfire();
        imp = new BonfireLogic();
        skinNft = new SkinNft("", 5);
        skinNft.init(address(bonfire));

        targets = [address(bonfire), address(bonfire)];
        calldatas = [abi.encode(beef, 100), abi.encode(20)];
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

        vm.prank(deployer);
        executor.setProxyAddress(address(proxy));

        bonfire.init(
            address(executor),
            "ChainInsight",
            "SBT",
            "https://thechaininsight.github.io/bonfire/",
            20 ether,
            address(skinNft),
            address(imp)
        );

        // mint SBT to obtain voting right
        vm.deal(proposer, 10000 ether);
        vm.prank(proposer);
        address(bonfire).call{value: 20 ether}(
            abi.encodeWithSignature("mint()")
        );

        vm.deal(voter, 10000 ether);
        vm.prank(voter);
        address(bonfire).call{value: 20 ether}(
            abi.encodeWithSignature("mint()")
        );

        vm.deal(beef, 10000 ether);
        vm.prank(beef);
        address(bonfire).call{value: 20 ether}(
            abi.encodeWithSignature("mint()")
        );

        // set block.number to 0

        vm.roll(0);

        // propose
        vm.prank(proposer);

        address(proxy).call(
            abi.encodeWithSignature(
                "propose(address[],uint256[],string[],bytes[],string)",
                targets,
                values,
                signatures,
                calldatas,
                description
            )
        );

        // voting starts
        vm.roll(votingDelay + 1);
        vm.prank(voter);
        address(proxy).call(
            abi.encodeWithSignature("castVote(uint256,uint8)", 1, 1)
        );

        // voting ends
        vm.roll(votingDelay + votingPeriod + 1);

        // queue proposal
        address(proxy).call(abi.encodeWithSignature("queue(uint256)", 1));
        etas = [block.number + executingDelay, block.number + executingDelay];
        txHashs[0] = keccak256(
            abi.encode(targets[0], values[0], signatures[0], calldatas[0], etas[0])
        );
        txHashs[1] = keccak256(
            abi.encode(targets[1], values[1], signatures[1], calldatas[1], etas[1])
        );

    }

    function testExecute() public {
        assertEq(bonfire.monthlyDistributedFavoNum(), 10);

        assertTrue(executor.queuedTransactions(txHashs[0]));
        assertTrue(executor.queuedTransactions(txHashs[1]));
        vm.roll(votingDelay + votingPeriod + executingDelay + 1);
        address(proxy).call(abi.encodeWithSignature("execute(uint256)", 1));
        assertEq(skinNft.ownerOf(1), beef);
        assertEq(bonfire.monthlyDistributedFavoNum(), 20);
    }

    receive() external payable {}
}
