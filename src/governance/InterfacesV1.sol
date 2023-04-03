pragma solidity ^0.8.16;

import "../bonfire/IBonfireProxy.sol";

contract ChainInsightGovernanceEventsV1 {
    /// @notice An event emitted when a new proposal is created
    event ProposalCreated(
        uint256 id,
        address proposer,
        address[] targets,
        uint256[] values,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );

    /// @notice An event emitted when a vote has been cast on a proposal
    /// @param voter The address which casted a vote
    /// @param proposalId The proposal id which was voted on
    /// @param support Support value for the vote. 0=against, 1=for, 2=abstain
    /// @param votes Number of votes which were cast by the voter
    /// @param reason The reason given for the vote by the voter
    event VoteCast(
        address indexed voter,
        uint256 proposalId,
        uint8 support,
        uint256 votes,
        string reason
    );

    /// @notice An event emitted when a proposal has been canceled
    event ProposalCanceled(uint256 id);

    /// @notice An event emitted when a proposal has been queued in the ChainInsightExecutor
    event ProposalQueued(uint256 id, uint256 eta);

    /// @notice An event emitted when a proposal has been executed in the ChainInsightExecutor
    event ProposalExecuted(uint256 id);

    /// @notice An event emitted when a proposal has been vetoed by vetoAddress
    event ProposalVetoed(uint256 id);

    /// @notice An event emitted when the executing delay is set
    event ExecutingDelaySet(
        uint256 oldExecutingDelay,
        uint256 newExecutingDelay
    );

    /// @notice An event emitted when the executing grace period is set
    event ExecutingGracePeriodSet(
        uint256 oldExecutingGracePeriod,
        uint256 newExecutingGracePeriod
    );

    /// @notice An event emitted when the voting delay is set
    event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);

    /// @notice An event emitted when the proposal threshold is set
    event ProposalThresholdSet(
        uint256 oldProposalThreshold,
        uint256 newProposalThreshold
    );

    /// @notice An event emitted when the voting period is set
    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);

    /// @notice Emitted when implementation is changed
    event NewImplementation(
        address oldImplementation,
        address newImplementation
    );

    // /// @notice Emitted when pendingAdmin is changed
    // event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /// @notice Emitted when executor is setted
    event NewExecutor(address oldExecutor, address newExecutor);

    /// @notice Emitted when pendingVetoer is changed.
    event NewPendingVetoer(address oldPendingVetoer, address newPendingVetoer);

    /// @notice Emitted when vetoer is changed
    event NewVetoer(address oldVetoer, address newVetoer);
}

contract ChainInsightGovernanceProxyStorage {
    /// @notice deployer address for proxy contract
    address public deployer;

    /// @notice address of executor contract
    address public executor;

    /// @notice Active brains of Governor
    address public implementation;
}

/**
 * @title Storage for Govenor Bravo Delegate
 * @notice For future updates, do not change ChainInsightStorageV1. Create a new
 * contract which implements ChainInsightStorageV1 and following the naming convention
 * ChainInsightStorageVX.
 */
contract ChainInsightGovernanceStorageV1 is ChainInsightGovernanceProxyStorage {
    /// @notice Vetoer who has the ability to veto any proposal
    address public vetoer;

    /// @notice Pending new vetoer
    address public pendingVetoer;

    /// @notice Grace period for which transactions are allowed to stay in queueTransactions
    uint256 public executingGracePeriod;

    /// @notice The delay before executing a proposal takes place, once queued
    uint256 public executingDelay;

    /// @notice The duration of voting on a proposal, in blocks
    uint256 public votingPeriod;

    /// @notice The delay before voting on a proposal may take place, once proposed, in blocks
    uint256 public votingDelay;

    /// @notice The threshold grade required to propose
    uint256 public proposalThreshold;

    /// @notice The total number of proposals
    uint256 public proposalCount;

    // /// @notice The address of ChainInsightExecutor
    // IChainInsightExecutor public executorContract;

    /// @notice The address of ChainInsightExecutor
    IBonfire public bonfireContract;

    /// @notice The latest proposal for each proposer
    mapping(address => uint256) public latestProposalIds;

    /// @notice The official record of all proposals ever proposed
    mapping(uint256 => Proposal) public proposals;

    struct Proposal {
        /// @notice Unique id for looking up a proposal
        uint256 id;
        /// @notice Creator of the proposal
        address proposer;
        /// @notice The timestamp that the proposal will be available for execution, set once the vote succeeds
        uint256 eta;
        /// @notice the ordered list of target addresses for calls to be made
        address[] targets;
        /// @notice The ordered list of values (i.e. msg.value) to be passed to the calls to be made
        uint256[] values;
        /// @notice The ordered list of function signatures to be called
        string[] signatures;
        /// @notice The ordered list of calldata to be passed to each call
        bytes[] calldatas;
        /// @notice The block at which voting begins: holders must delegate their votes prior to this block
        uint256 startBlock;
        /// @notice The block at which voting ends: votes must be cast prior to this block
        uint256 endBlock;
        /// @notice Current number of votes in favor of this proposal
        uint256 forVotes;
        /// @notice Current number of votes in opposition to this proposal
        uint256 againstVotes;
        /// @notice Current number of votes for abstaining for this proposal
        uint256 abstainVotes;
        // TODO: stack too deep ...
        // /// @notice Flag marking whether the proposal has been canceled
        // bool canceled;
        // /// @notice Flag marking whether the proposal has been vetoed
        // bool vetoed;
        // /// @notice Flag marking whether the proposal has been executed
        // bool executed;
        // 0 -> no info, 1 -> executed, 2 -> canceled, 3 -> vetoed
        uint256 state;
        /// @notice Receipts of ballots for the entire set of voters
        mapping(address => Receipt) receipts;
    }

    /// @notice Ballot receipt record for a voter
    struct Receipt {
        /// @notice Whether or not a vote has been cast
        bool hasVoted;
        /// @notice Whether or not the voter supports the proposal or abstains
        uint8 support;
        /// @notice The number of votes the voter had, which were cast
        uint256 votes;
    }

    /// @notice Possible states that a proposal may be in
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed,
        Vetoed
    }
}

interface IChainInsightExecutor {
    // event NewProxyAddress(address indexed newProxyAddress);
    event NewProxyAddress(address oldProxyAddress, address newProxyAddress);

    event CancelTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );

    // function acceptProxyAddress() external;
    function setProxyAddress(address newProxyAddress) external;

    function transactionIsQueued(bytes32 txHash) external view returns (bool);

    function queueTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external returns (bytes32);

    function cancelTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external;

    function executeTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta,
        uint256 executingGracePeriod
    ) external payable returns (bytes memory);
}
