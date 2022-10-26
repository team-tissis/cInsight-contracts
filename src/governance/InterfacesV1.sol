pragma solidity ^0.8.16;

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
        uint256 proposalThreshold,
        string description
    );

    /// @notice An event emitted when a vote has been cast on a proposal
    /// @param voter The address which casted a vote
    /// @param proposalId The proposal id which was voted on
    /// @param support Support value for the vote. 0=against, 1=for, 2=abstain
    /// @param votes Number of votes which were cast by the voter
    /// @param reason The reason given for the vote by the voter
    event VoteCast(address indexed voter, uint256 proposalId, uint8 support, uint256 votes, string reason);

    /// @notice An event emitted when a proposal has been canceled
    event ProposalCanceled(uint256 id);

    /// @notice An event emitted when a proposal has been queued in the ChainInsightExecutor
    event ProposalQueued(uint256 id, uint256 eta);

    /// @notice An event emitted when a proposal has been executed in the ChainInsightExecutor
    event ProposalExecuted(uint256 id);

    /// @notice An event emitted when the executing delay is set
    event ExecutingDelaySet(uint256 oldExecutingDelay, uint256 newExecutingDelay);

    /// @notice An event emitted when the executing grace period is set
    event ExecutingGracePeriodSet(uint256 oldExecutingGracePeriod, uint256 newExecutingGracePeriod);

    /// @notice An event emitted when the voting delay is set
    event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);

    /// @notice An event emitted when the voting period is set
    event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);

    /** メモ: @terapoon
     * TODO: Proxy 周りに関係しているイベントか？
     */
    /// @notice Emitted when implementation is changed
    event NewImplementation(address oldImplementation, address newImplementation);

    /// @notice Emitted when pendingAdmin is changed
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /// @notice Emitted when pendingAdmin is accepted, which means admin is updated
    event NewAdmin(address oldAdmin, address newAdmin);
}


contract ChainInsightGovernanceProxyStorage {
    /// @notice Administrator for this contract
    address public admin;

    /// @notice Pending administrator for this contract
    address public pendingAdmin;

    /** メモ: @terapoon
     * ChainInsightLogic (V1, V2) の contract address がはいる。
     */
    /// @notice Active brains of Governor
    address public implementation;
}

/** メモ: @terapoon
 * 今後のアップデートの際のルールとして、これまでの ChainInsightStorageV1 を継承し、ChainInsightStorageVX という命名で
 * アップデートを行えと指示されている。
 */
/**
 * @title Storage for Govenor Bravo Delegate
 * @notice For future updates, do not change ChainInsightStorageV1. Create a new
 * contract which implements ChainInsightStorageV1 and following the naming convention
 * ChainInsightStorageVX.
 */
contract ChainInsightGovernanceStorageV1 is ChainInsightGovernanceProxyStorage {
    /// @notice Grace period for which transactions are allowed to stay in queueTransactions
    uint256 public executingGracePeriod;

    /// @notice The delay before executing a proposal takes place, once queued
    uint256 public executingDelay;

    /** メモ: @terapoon
     * 提案後すぐに投票に移るのではなく、delay の分だけ待ち時間が生じるようだ。
     */
    /// @notice The delay before voting on a proposal may take place, once proposed, in blocks
    uint256 public votingDelay;

    /** メモ: @terapoon
     * 投票期間も設定されている。
     */
    /// @notice The duration of voting on a proposal, in blocks
    uint256 public votingPeriod;

    /// @notice The total number of proposals
    uint256 public proposalCount;

    /** メモ: @terapoon
     * IChainInsightExecutor を継承しているものにはアップデートが可能。
     */
    /// @notice The address of ChainInsightExecutor
    IChainInsightExecutor public executorContract;

    /** メモ: @terapoon
     * 各 proposer の最後の proposal の一覧。最新のものしか保持していない。
     */
    /// @notice The latest proposal for each proposer
    mapping(address => uint256) public latestProposalIds; 

    /// @notice The official record of all proposals ever proposed
    mapping(uint256 => Proposal) public proposals;

    struct Proposal {
        /// @notice Unique id for looking up a proposal
        uint256 id;
        /// @notice Creator of the proposal
        address proposer;

        /** メモ: @terapoon
         * Proposal の作成に必要な票数が設定できるようだ。
         */
        /// @notice The number of votes needed to create a proposal at the time of proposal creation. *DIFFERS from GovernerBravo
        uint256 proposalThreshold;

        /** メモ: @terapoon
         * 投票の結果実行できるようになった proposal が実行可能となる時間のタイムスタンプ。
         */
        /// @notice The timestamp that the proposal will be available for execution, set once the vote succeeds
        uint256 eta;

        /** メモ: @terapoon
         * Proposal の実行に必要な情報たちが格納されている。
         */
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

        /** メモ: @terapoon
         * 現在の賛成の票数。
         */
        /// @notice Current number of votes in favor of this proposal
        uint256 forVotes;

        /** メモ: @terapoon
         * 現在の反対の票数。
         */
        /// @notice Current number of votes in opposition to this proposal
        uint256 againstVotes;

        /** メモ: @terapoon
         * 現在の棄権した票数。
         */
        /// @notice Current number of votes for abstaining for this proposal
        uint256 abstainVotes;

        /** メモ: @terapoon
         * この proposal がキャンセルされた、拒否された、実行されたなどの情報を表すフラグ。
         */
        /// @notice Flag marking whether the proposal has been canceled
        bool canceled;
        /// @notice Flag marking whether the proposal has been vetoed
        bool vetoed;
        /// @notice Flag marking whether the proposal has been executed
        bool executed;

        /** メモ: @terapoon
         * 投票者それぞれに対する投票を受理したことを証明する受領票 (receipt) を管理するマッピング。
         */
        /// @notice Receipts of ballots for the entire set of voters
        mapping(address => Receipt) receipts;
    }

    /** メモ: @terapoon
     * 投票の受理票。投票の有無、賛成か反対か棄権か、表の数、の３つの情報を記録している。
     */
    /// @notice Ballot receipt record for a voter
    struct Receipt {
        /// @notice Whether or not a vote has been cast
        bool hasVoted;
        /// @notice Whether or not the voter supports the proposal or abstains
        uint8 support;
        /// @notice The number of votes the voter had, which were cast
        uint96 votes;
    }

    /** メモ: @terapoon
     * Proposal の状態の一覧。
     * Pending: 提案が作成されてから投票が始まるまでの間
     * Active: 投票期間中
     * Canceled: 提案した人が提案を取り下げた or 途中で Delegation が足りなくなって取り下げられた
     * Defeated: 投票で敗北した
     * Succeeded: 投票で勝利した
     * Queued: キューに入った
     * Expired: 実行期限が過ぎているが実行されなかったために破棄された
     * Executed: 実行された
     */
    /// @notice Possible states that a proposal may be in
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }
}

interface IChainInsightExecutor {
    // event NewLogicAddress(address indexed newLogicAddress);
     event NewLogicAddress(address oldLogicAddress, address newLogicAddress);

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

    // function acceptLogicAddress() external;
    function setLogicAddress(address newLogicAddress) external;

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
