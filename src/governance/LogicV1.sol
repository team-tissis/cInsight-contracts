pragma solidity ^0.8.16;

import "./InterfacesV1.sol";
import "../libs/SbtLib.sol";

contract ChainInsightLogicV1 is
    ChainInsightGovernanceStorageV1,
    ChainInsightGovernanceEventsV1
{
    /// @notice The name of this contract
    string public constant name = "Chain Insight Governance";

    /// @notice The minimum setable executing grace period
    uint256 public constant MIN_EXECUTING_GRACE_PERIOD = 11_520; // About 2 days
    /// @notice The maximum setable executing grace period
    uint256 public constant MAX_EXECUTING_GRACE_PERIOD = 172_800; // About 30 days

    /// @notice The min setable executing delay
    uint256 public constant MIN_EXECUTING_DELAY = 11_520;

    /// @notice The max setable executing delay
    uint256 public constant MAX_EXECUTING_DELAY = 172_800;

    /// @notice The minimum setable voting period
    uint256 public constant MIN_VOTING_PERIOD = 5_760; // About 24 hours

    /// @notice The max setable voting period
    uint256 public constant MAX_VOTING_PERIOD = 80_640; // Abount 2 weeks

    /// @notice The min setable voting delay
    uint256 public constant MIN_VOTING_DELAY = 1;

    /// @notice The max setable voting delay
    uint256 public constant MAX_VOTING_DELAY = 40_320; // About 1 week

    /// @notice The min setable proposal threshold
    uint256 public constant MIN_PROPOSAL_THRESHOLD = 1;

    /// @notice The max setable voting threshold
    uint256 public constant MAX_PROPOSAL_THRESHOLD = 5;

    /// @notice The maximum number of actions that can be included in a proposal
    uint256 public constant proposalMaxOperations = 10; // 10 actions

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,uint256 chainId,address verifyingContract)"
        );

    /// @notice The EIP-712 typehash for the ballot struct used by the contract
    bytes32 public constant BALLOT_TYPEHASH =
        keccak256("Ballot(uint256 proposalId,uint8 support)");

    /**
     * @notice Used to initialize the contract during delegator contructor
     * @param executorContract_ The address of the Executor
     * @param vetoer_ The address allowed to unilaterally veto proposals
     * @param votingPeriod_ The initial voting period
     * @param votingDelay_ The initial voting delay
     */
    function initialize(
        address executorContract_,
        address vetoer_,
        uint256 executingGracePeriod_,
        uint256 executingDelay_,
        uint256 votingPeriod_,
        uint256 votingDelay_,
        uint256 proposalThreshold_
    ) public {
        require(
            address(executorContract) == address(0),
            "LogicV1::initialize: can only initialize once"
        );

        require(
            executorContract_ != address(0),
            "LogicV1::initialize: invalid Executor address"
        );

        require(
            executingGracePeriod_ >= MIN_EXECUTING_GRACE_PERIOD &&
                executingGracePeriod_ <= MAX_EXECUTING_GRACE_PERIOD,
            "LogicV1::initialize: invalid executing grace period"
        );
        require(
            executingDelay_ >= MIN_EXECUTING_DELAY &&
                executingDelay_ <= MAX_EXECUTING_DELAY,
            "LogicV1::initialize: invalid executing delay"
        );

        require(
            votingPeriod_ >= MIN_VOTING_PERIOD &&
                votingPeriod_ <= MAX_VOTING_PERIOD,
            "LogicV1::initialize: invalid voting period"
        );
        require(
            votingDelay_ >= MIN_VOTING_DELAY &&
                votingDelay_ <= MAX_VOTING_DELAY,
            "LogicV1::initialize: invalid voting delay"
        );

        require(
            proposalThreshold_ >= MIN_PROPOSAL_THRESHOLD &&
                votingDelay_ <= MAX_PROPOSAL_THRESHOLD,
            "LogicV1::initialize: invalid voting delay"
        );

        emit ExecutingGracePeriodSet(
            executingGracePeriod,
            executingGracePeriod_
        );
        emit ExecutingDelaySet(executingDelay, executingDelay_);
        emit VotingPeriodSet(votingPeriod, votingPeriod_);
        emit VotingDelaySet(votingDelay, votingDelay_);
        emit ProposalThresholdSet(proposalThreshold, proposalThreshold_);

        executorContract = IChainInsightExecutor(executorContract_);
        vetoer = vetoer_;

        executingGracePeriod = executingGracePeriod_;
        executingDelay = executingDelay_;
        votingPeriod = votingPeriod_;
        votingDelay = votingDelay_;
    }

    /**
     * @notice Function used to propose a new proposal. Sender must have delegates above the proposal threshold
     * @param targets Target addresses for proposal calls
     * @param values Eth values for proposal calls
     * @param signatures Function signatures for proposal calls
     * @param calldatas Calldatas for proposal calls
     * @param description String description of the proposal
     * @return Proposal id of new proposal
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint256) {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();

        // require(
        //     sbtstruct.grade[msg.sender] >= proposalThreshold,
        //     'LogicV1::propose: proposer must hold Bonfire SBT'
        // );

        require(
            targets.length == values.length &&
                targets.length == signatures.length &&
                targets.length == calldatas.length,
            "LogicV1::propose: proposal function information arity mismatch"
        );
        require(targets.length != 0, "LogicV1::propose: must provide actions");
        require(
            targets.length <= proposalMaxOperations,
            "LogicV1::propose: too many actions"
        );

        /// @notice Ensure that msg.sender currently does not have active or pending proposals
        uint256 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
            ProposalState proposersLatestProposalState = state(
                latestProposalId
            );
            require(
                proposersLatestProposalState != ProposalState.Active,
                "LogicV1::propose: one live proposal per proposer, found an already active proposal"
            );
            require(
                proposersLatestProposalState != ProposalState.Pending,
                "LogicV1::propose: one live proposal per proposer, found an already pending proposal"
            );
        }

        /// @notice ID of initial proposal is 1.
        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];

        newProposal.id = proposalCount;
        newProposal.proposer = msg.sender;
        newProposal.eta = 0;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.signatures = signatures;
        newProposal.calldatas = calldatas;
        newProposal.startBlock = block.number + votingDelay;
        newProposal.endBlock = newProposal.startBlock + votingPeriod;
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;
        newProposal.abstainVotes = 0;
        newProposal.canceled = false;
        newProposal.executed = false;
        newProposal.vetoed = false;

        latestProposalIds[msg.sender] = newProposal.id;

        /// @notice Maintains backwards compatibility with GovernorBravo events
        emit ProposalCreated(
            newProposal.id,
            msg.sender,
            targets,
            values,
            signatures,
            calldatas,
            newProposal.startBlock,
            newProposal.endBlock,
            description
        );

        return newProposal.id;
    }

    /**
     * @notice Queues a proposal of state succeeded
     * @param proposalId The id of the proposal to queue
     */
    function queue(uint256 proposalId) external {
        require(
            state(proposalId) == ProposalState.Succeeded,
            "LogicV1::queue: proposal can only be queued if it is succeeded"
        );
        Proposal storage proposal = proposals[proposalId];

        uint256 eta = block.timestamp + executingDelay;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            queueOrRevertInternal(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                eta
            );
        }
        proposal.eta = eta;
        emit ProposalQueued(proposalId, eta);
    }

    /// @notice stop queueing if the proposal is already queued
    function queueOrRevertInternal(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) internal {
        require(
            !executorContract.transactionIsQueued(
                keccak256(abi.encode(target, value, signature, data, eta))
            ),
            "LogicV1::queueOrRevertInternal: identical proposal action already queued at eta"
        );
        executorContract.queueTransaction(target, value, signature, data, eta);
    }

    /**
     * @notice Executes a queued proposal if eta has passed
     * @param proposalId The id of the proposal to execute
     */
    function execute(uint256 proposalId) external {
        require(
            state(proposalId) == ProposalState.Queued,
            "LogicV1::execute: proposal can only be executed if it is queued"
        );
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;

        for (uint256 i = 0; i < proposal.targets.length; i++) {
            executorContract.executeTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta,
                executingGracePeriod
            );
        }
        emit ProposalExecuted(proposalId);
    }

    /**
     * @notice Cancels a proposal only if sender is the proposer, or proposer delegates dropped below proposal threshold
     * @param proposalId The id of the proposal to cancel
     */
    function cancel(uint256 proposalId) external {
        require(
            state(proposalId) != ProposalState.Executed,
            "LogicV1::cancel: cannot cancel executed proposal"
        );

        Proposal storage proposal = proposals[proposalId];
        require(
            msg.sender == proposal.proposer,
            "LogicV1::cancel: only proposer can cancel proposal"
        );

        proposal.canceled = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            executorContract.cancelTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }

        emit ProposalCanceled(proposalId);
    }

    /**
     * @notice Vetoes a proposal only if sender is the vetoer and the proposal has not been executed.
     * @param proposalId The id of the proposal to veto
     */
    function veto(uint256 proposalId) external {
        require(vetoer != address(0), "LogicV1::veto: veto power burned");
        require(msg.sender == vetoer, "LogicV1::veto: only vetoer");
        require(
            state(proposalId) != ProposalState.Executed,
            "LogicV1::veto: cannot veto executed proposal"
        );

        Proposal storage proposal = proposals[proposalId];

        proposal.vetoed = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            executorContract.cancelTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }

        emit ProposalVetoed(proposalId);
    }

    /**
     * @notice Gets the receipt for a voter on a given proposal
     * @param proposalId the id of proposal
     * @param voter The address of the voter
     * @return The voting receipt
     */
    function getReceipt(uint256 proposalId, address voter)
        external
        view
        returns (Receipt memory)
    {
        return proposals[proposalId].receipts[voter];
    }

    /**
     * @notice Gets the state of a proposal
     * @param proposalId The id of the proposal
     * @return Proposal state
     */
    function state(uint256 proposalId) public view returns (ProposalState) {
        require(
            proposalCount >= proposalId,
            "LogicV1::state: invalid proposal id"
        );

        Proposal storage proposal = proposals[proposalId];
        if (proposal.vetoed) {
            return ProposalState.Vetoed;
        } else if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes) {
            return ProposalState.Defeated;
        } else if (proposal.eta == 0) {
            return ProposalState.Succeeded;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= proposal.eta + executingGracePeriod) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    /**
     * @notice Cast a vote for a proposal
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     */
    function castVote(uint256 proposalId, uint8 support) external {
        emit VoteCast(
            msg.sender,
            proposalId,
            support,
            castVoteInternal(msg.sender, proposalId, support),
            ""
        );
    }

    /**
     * @notice Cast a vote for a proposal with a reason
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     * @param reason The reason given for the vote by the voter
     */
    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external {
        emit VoteCast(
            msg.sender,
            proposalId,
            support,
            castVoteInternal(msg.sender, proposalId, support),
            reason
        );
    }

    /**
     * @notice Cast a vote for a proposal by signature
     * @dev External function that accepts EIP-712 signatures for voting on proposals.
     */
    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                getChainIdInternal(),
                address(this)
            )
        );
        bytes32 structHash = keccak256(
            abi.encode(BALLOT_TYPEHASH, proposalId, support)
        );
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainSeparator, structHash)
        );
        address signatory = ecrecover(digest, v, r, s);
        require(
            signatory != address(0),
            "LogicV1::castVoteBySig: invalid signature"
        );
        emit VoteCast(
            signatory,
            proposalId,
            support,
            castVoteInternal(signatory, proposalId, support),
            ""
        );
    }

    /**
     * @notice Internal function that caries out voting logic
     * @param voter The voter that is casting their vote
     * @param proposalId The id of the proposal to vote on
     * @param support The support value for the vote. 0=against, 1=for, 2=abstain
     * @return The number of votes cast
     */
    function castVoteInternal(
        address voter,
        uint256 proposalId,
        uint8 support
    ) internal returns (uint96) {
        require(
            state(proposalId) == ProposalState.Active,
            "LogicV1::castVoteInternal: voting is closed"
        );

        require(support <= 2, "LogicV1::castVoteInternal: invalid vote type");
        Proposal storage proposal = proposals[proposalId];

        Receipt storage receipt = proposal.receipts[voter];
        require(
            receipt.hasVoted == false,
            "LogicV1::castVoteInternal: voter already voted"
        );

        /// @notice retrieve voting weight of voter
        uint96 votes = getVotes(voter);

        require(votes > 0, "LogicV1::propose: voter must hold Bonfire SBT");

        if (support == 0) {
            proposal.againstVotes = proposal.againstVotes + votes;
        } else if (support == 1) {
            proposal.forVotes = proposal.forVotes + votes;
        } else if (support == 2) {
            proposal.abstainVotes = proposal.abstainVotes + votes;
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        return votes;
    }

    /**
     * @notice Admin function for setting the executing grace period
     * @param newExecutingGracePeriod new executing grace period
     */
    function _setExecutingGracePeriod(uint256 newExecutingGracePeriod) public {
        require(
            msg.sender == admin,
            "Executor::_setExecutingDelay: admin only"
        );
        uint256 oldExecutingGracePeriod = executingGracePeriod;
        executingGracePeriod = newExecutingGracePeriod;

        emit ExecutingGracePeriodSet(
            oldExecutingGracePeriod,
            newExecutingGracePeriod
        );
    }

    /**
     * @notice Admin function for setting the executing delay
     * @param newExecutingDelay new executing delay
     */
    function _setExecutingDelay(uint256 newExecutingDelay) public {
        require(
            msg.sender == admin,
            "Executor::_setExecutingDelay: admin only"
        );
        uint256 oldExecutingDelay = executingDelay;
        executingDelay = newExecutingDelay;

        emit ExecutingDelaySet(oldExecutingDelay, newExecutingDelay);
    }

    /**
     * @notice Admin function for setting the voting delay
     * @param newVotingDelay new voting delay, in blocks
     */
    function _setVotingDelay(uint256 newVotingDelay) external {
        require(msg.sender == admin, "LogicV1::_setVotingDelay: admin only");
        require(
            newVotingDelay >= MIN_VOTING_DELAY &&
                newVotingDelay <= MAX_VOTING_DELAY,
            "LogicV1::_setVotingDelay: invalid voting delay"
        );
        uint256 oldVotingDelay = votingDelay;
        votingDelay = newVotingDelay;

        emit VotingDelaySet(oldVotingDelay, votingDelay);
    }

    /**
     * @notice Admin function for setting the voting period
     * @param newVotingPeriod new voting period, in blocks
     */
    function _setVotingPeriod(uint256 newVotingPeriod) external {
        require(msg.sender == admin, "LogicV1::_setVotingPeriod: admin only");
        require(
            newVotingPeriod >= MIN_VOTING_PERIOD &&
                newVotingPeriod <= MAX_VOTING_PERIOD,
            "LogicV1::_setVotingPeriod: invalid voting period"
        );
        uint256 oldVotingPeriod = votingPeriod;
        votingPeriod = newVotingPeriod;

        emit VotingPeriodSet(oldVotingPeriod, votingPeriod);
    }

    /**
     * @notice Admin function for setting the proposal threshold
     * @param newProposalThreshold new proposal threshold, in blocks
     */
    function _setProposalThreshold(uint256 newProposalThreshold) external {
        require(
            msg.sender == admin,
            "LogicV1::_setProposalThreshold: admin only"
        );
        require(
            newProposalThreshold >= MIN_PROPOSAL_THRESHOLD &&
                newProposalThreshold <= MAX_PROPOSAL_THRESHOLD,
            "LogicV1::_setVotingPeriod: invalid proposal threshold"
        );
        uint256 oldProposalThreshold = proposalThreshold;
        proposalThreshold = newProposalThreshold;

        emit ProposalThresholdSet(oldProposalThreshold, proposalThreshold);
    }

    /**
     * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
     * @param newPendingAdmin New pending admin.
     */
    function _setPendingAdmin(address newPendingAdmin) external {
        require(msg.sender == admin, "LogicV1::_setPendingAdmin: admin only");

        // Save current value, if any, for inclusion in log
        address oldPendingAdmin = pendingAdmin;

        // Store pendingAdmin with value newPendingAdmin
        pendingAdmin = newPendingAdmin;

        emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);
    }

    /**
     * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
     * @dev Admin function for pending admin to accept role and update admin
     */
    function _acceptAdmin() external {
        require(
            msg.sender == pendingAdmin && msg.sender != address(0),
            "LogicV1::_acceptAdmin: pending admin only"
        );

        // Save current values for inclusion in log
        address oldAdmin = admin;
        address oldPendingAdmin = pendingAdmin;

        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = address(0);

        emit NewAdmin(oldAdmin, admin);
        emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
    }

    /**
     * @notice Begins transition of vetoer. The newPendingVetoer must call _acceptVetoer to finalize the transfer.
     * @param newPendingVetoer New Pending Vetoer
     */
    function _setPendingVetoer(address newPendingVetoer) public {
        require(msg.sender == vetoer, "LogicV1::veto: vetoer only");

        emit NewPendingVetoer(pendingVetoer, newPendingVetoer);

        pendingVetoer = newPendingVetoer;
    }

    function _acceptVetoer() external {
        require(
            msg.sender == pendingVetoer && msg.sender != address(0),
            "LogicV1::veto: pending vetoer only"
        );

        // Update vetoer
        emit NewVetoer(vetoer, pendingVetoer);
        vetoer = pendingVetoer;

        // Clear the pending value
        emit NewPendingVetoer(pendingVetoer, address(0));
        pendingVetoer = address(0);
    }

    /**
     * @notice Burns veto priviledges
     * @dev Vetoer function destroying veto power forever
     */
    function _burnVetoPower() public {
        // Check caller is vetoer
        require(msg.sender == vetoer, "LogicV1::_burnVetoPower: vetoer only");

        // Update vetoer to 0x0
        emit NewVetoer(vetoer, address(0));
        vetoer = address(0);

        // Clear the pending value
        emit NewPendingVetoer(pendingVetoer, address(0));
        pendingVetoer = address(0);
    }

    function getChainIdInternal() internal view returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }

    function getVotes(address voter) internal view returns (uint96) {
        SbtLib.SbtStruct storage sbtstruct = SbtLib.sbtStorage();
        // uint96 votes = sbtstruct.grade[voter];
        // return votes;
    }
}
